require 'optparse'
require 'singleton'

# CLI runner
class PushmiPullyu::CLI

  include Singleton
  include PushmiPullyu::Logging

  COMMANDS = ['start', 'stop', 'restart', 'reload', 'run', 'zap', 'status'].freeze

  attr_accessor :config

  def initialize
    self.config = PushmiPullyu::Config.new
    @running = true # set to false by interrupt signal trap
    @reset_logger = false # set to true by SIGHUP trap
  end

  def parse(args = ARGV)
    parse_options(args)
    parse_commands(args)
  end

  def run
    if config.daemonize
      start_server_as_daemon
    else
      # If we're running in the foreground sync the output.
      $stdout.sync = $stderr.sync = true
      start_server
    end
  end

  def start_server
    setup_signal_traps

    setup_log
    print_banner

    setup_queue

    run_tick_loop
  end

  private

  def parse_commands(argv)
    config.daemonize = true if COMMANDS.include? argv[0]
  end

  # Parse the options.
  def parse_options(argv)
    @parsed_opts = OptionParser.new do |opts|
      opts.banner = 'Usage: pushmi_pullyu [options] [start|stop|restart|run]'
      opts.separator ''
      opts.separator 'Specific options:'

      opts.on('-a', '--minimum-age AGE', Float, 'Minimum amount of time an item must spend in the queue, in seconds.'\
              " (Default: #{config.minimum_age})") do |minimum_age|
        config.minimum_age = minimum_age
      end

      opts.on('-d', '--debug', 'Enable debug logging') do
        config.debug = true
      end

      opts.on('-L', '--logfile PATH', "Path to writable logfile (Default: #{config.logfile})") do |logfile|
        config.logfile = logfile
      end

      opts.on('-D', '--piddir PATH', "Path to piddir (Default: #{config.piddir})") do |piddir|
        config.piddir = piddir
      end

      opts.on('-N', '--process_name NAME', "Name of the process (Default: #{config.process_name})") do |process_name|
        config.process_name = process_name
      end

      opts.on('-m', '--monitor', "Start monitor process for a deamon (Default #{config.monitor})") do
        config.monitor = true
      end

      opts.on('-rh', '--redis-host IP', 'Host IP of Redis instance to read from.'\
              " (Default: #{config.redis_host})") do |ip|
        config.redis_host = ip
      end

      opts.on('-rp', '--redis-port PORT', OptionParser::DecimalInteger,
              "Port of Redis instance to read from. (Default: #{config.redis_port})") do |port|
        config.redis_port = port
      end

      opts.on('-q', '--queue NAME', "Name of the queue to read from. (Default: #{config.queue_name})") do |queue|
        config.queue_name = queue
      end

      opts.separator ''
      opts.separator 'Common options:'

      opts.on_tail('-v', '--version', 'Show version') do
        puts "PushmiPullyu version: #{PushmiPullyu::VERSION}"
        exit
      end

      opts.on_tail('-h', '--help', 'Show this message') do
        puts opts
        exit
      end
    end.parse!(argv)
  end

  def print_banner
    logger.info "Loading PushmiPullyu #{PushmiPullyu::VERSION}"
    logger.info "Running in #{RUBY_DESCRIPTION}"
    logger.info 'Starting processing, hit Ctrl-C to stop' unless config.daemonize
  end

  def rotate_logs
    PushmiPullyu::Logging.reopen
    Daemonize.redirect_io(config.logfile) if config.daemonize
    @reset_logger = false
  end

  def run_tick_loop
    while running?
      # Preservation (TODO):
      # 1. Montior queue
      # 2. Pop off GenericFile element off queue that are ready to begin process preservation event
      item = @queue.wait_next_item
      logger.debug(item)
      # 3. Retrieve GenericFile data in fedora
      # 4. creation of AIP
      # 5. bagging and tarring of AIP
      # 6. Push bag to swift API
      # 7. Log successful preservation event to log files

      rotate_logs if @reset_logger
    end
  end

  def running?
    @running
  end

  def setup_log
    if config.daemonize
      PushmiPullyu::Logging.initialize_logger(config.logfile)
    else
      logger.formatter = PushmiPullyu::Logging::SimpleFormatter.new
    end
    logger.level = ::Logger::DEBUG if config.debug
  end

  def setup_signal_traps
    Signal.trap('INT') { shutdown }
    Signal.trap('TERM') { shutdown }
    Signal.trap('HUP') { @reset_logger = true }
  end

  def setup_queue
    @queue = PushmiPullyu::PreservationQueue.new(connection: { host: config.redis_host, port: config.redis_port },
                                                 queue_name: config.queue_name,
                                                 age_at_least: config.minimum_age)
  end

  # On first call of shutdown, this will gracefully close the main run loop
  # which let's the program exit itself. Calling shutdown again will force shutdown the program
  def shutdown
    exit!(1) unless running?
    # using stderr instead of logger as it uses an underlying mutex which is not allowed inside trap contexts.
    $stderr.puts 'Exiting...  Interrupt again to force quit.'
    @running = false
  end

  def start_server_as_daemon
    require 'daemons'

    pwd = Dir.pwd # Current directory is changed during daemonization, so store it

    options = {
      ARGV:       @parsed_opts,
      dir:        config.piddir,
      dir_mode:   :normal,
      monitor:    config.monitor,
      log_output: true,
      log_dir: File.join(pwd, File.dirname(config.logfile)),
      logfilename: File.basename(config.logfile),
      output_logfilename: File.basename(config.logfile)
    }

    Daemons.run_proc(config.process_name, options) do |*_argv|
      Dir.chdir(pwd)
      start_server
    end
  end

end

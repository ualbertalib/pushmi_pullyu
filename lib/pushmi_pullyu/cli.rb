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

    begin
      run_tick_loop
    rescue Interrupt
      logger.info 'Shutting down'
      @running = false
      logger.info 'Bye!'
      exit(0)
    end
  end

  private

  def setup_signal_traps
    Signal.trap('INT') { raise Interrupt }
    Signal.trap('TERM') { raise Interrupt }
    Signal.trap('HUP') do
      if config.logfile
        logger.debug 'Received SIGHUP, reopening log file'
        # TODO: reopen logs
        # PushmiPullyu::Logging.reopen_logs(config.logfile)
      end
    end
  end

  def parse_commands(argv)
    config.daemonize = true if COMMANDS.include? argv[0]
  end

  # Parse the options.
  def parse_options(argv)
    @options = OptionParser.new do |opts|
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

  def setup_log
    if config.daemonize
      PushmiPullyu::Logging.initialize_logger(config.logfile)
    else
      logger.formatter = PushmiPullyu::Logging::SimpleFormatter.new
    end
    logger.level = ::Logger::DEBUG if config.debug
  end

  def run_tick_loop
    queue = PushmiPullyu::PreservationQueue.new(connection: { host: config.redis_host, port: config.redis_port },
                                                queue_name: config.queue_name,
                                                age_at_least: config.minimum_age)

    @running = true # set to false by signal trap

    while @running
      # Preservation (TODO):
      # 1. Montior queue
      # 2. Pop off GenericFile element off queue that are ready to begin process preservation event
      item = queue.wait_next_item
      logger.debug(item)
      # 3. Retrieve GenericFile data in fedora
      # 4. creation of AIP
      # 5. bagging and tarring of AIP
      # 6. Push bag to swift API
      # 7. Log successful preservation event to log files
    end
  end

  def start_server_as_daemon
    require 'daemons'

    pwd = Dir.pwd # Current directory is changed during daemonization, so store it
    Daemons.run_proc(config.process_name, dir: config.piddir,
                                          dir_mode: :normal,
                                          monitor: config.monitor,
                                          ARGV: @options) do |*_argv|

      Dir.chdir(pwd)
      start_server
    end
  end

end

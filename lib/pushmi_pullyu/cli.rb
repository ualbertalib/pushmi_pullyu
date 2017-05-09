require 'erb'
require 'fileutils'
require 'optparse'
require 'singleton'
require 'yaml'

# CLI runner
class PushmiPullyu::CLI

  include Singleton
  include PushmiPullyu::Logging

  COMMANDS = ['start', 'stop', 'restart', 'reload', 'run', 'zap', 'status'].freeze

  def initialize; end

  def parse(argv = ARGV)
    opts = parse_options(argv)
    opts[:daemonize] = true if COMMANDS.include? argv[0]
    opts = parse_config(opts[:config_file]).merge(opts) if opts[:config_file]

    options.merge!(opts)
  end

  def run
    if options[:daemonize]
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

  def options
    PushmiPullyu.options
  end

  def setup_signal_traps
    Signal.trap('INT') { raise Interrupt }
    Signal.trap('TERM') { raise Interrupt }
    Signal.trap('HUP') do
      if options[:logfile]
        logger.debug 'Received SIGHUP, reopening log file'
        # TODO: reopen logs
        # PushmiPullyu::Logging.reopen_logs(options[:logfile])
      end
    end
  end

  def parse_config(config_file)
    opts = {}
    if File.exist?(config_file)
      opts = YAML.safe_load(ERB.new(IO.read(config_file)).result).deep_symbolize_keys || opts
    end

    opts
  end

  # Parse the options.
  def parse_options(argv)
    opts = {}

    @arguments = OptionParser.new do |o|
      o.banner = 'Usage: pushmi_pullyu [options] [start|stop|restart|run]'
      o.separator ''
      o.separator 'Specific options:'

      o.on('-a', '--minimum-age AGE',
           Float, 'Minimum amount of time an item must spend in the queue, in seconds.') do |minimum_age|
        opts[:minimum_age] = minimum_age
      end

      o.on('-d', '--debug', 'Enable debug logging') do
        opts[:debug] = true
      end

      o.on '-C', '--config PATH', 'path to YAML config file' do |config_file|
        opts[:config_file] = config_file
      end

      o.on('-L', '--logfile PATH', 'Path to writable logfile') do |logfile|
        opts[:logfile] = logfile
      end

      o.on('-D', '--piddir PATH', 'Path to piddir') do |piddir|
        opts[:piddir] = piddir
      end

      o.on('-N', '--process_name NAME', 'Name of the process') do |process_name|
        opts[:process_name] = process_name
      end

      o.on('-m', '--monitor', 'Start monitor process for a deamon') do
        opts[:monitor] = true
      end

      o.separator ''
      o.separator 'Common options:'

      o.on_tail('-v', '--version', 'Show version') do
        puts "PushmiPullyu version: #{PushmiPullyu::VERSION}"
        exit
      end

      o.on_tail('-h', '--help', 'Show this message') do
        puts o
        exit
      end
    end.parse!(argv)

    ['config/pushmi_pullyu.yml', 'config/pushmi_pullyu.yml.erb'].each do |filename|
      opts[:config_file] ||= filename if File.exist?(filename)
    end

    opts
  end

  def print_banner
    logger.info "Loading PushmiPullyu #{PushmiPullyu::VERSION}"
    logger.info "Running in #{RUBY_DESCRIPTION}"
    logger.info 'Starting processing, hit Ctrl-C to stop' unless options[:daemonize]
  end

  def setup_log
    if options[:daemonize]
      PushmiPullyu::Logging.initialize_logger(options[:logfile])
    else
      logger.formatter = PushmiPullyu::Logging::SimpleFormatter.new
    end
    logger.level = ::Logger::DEBUG if options[:debug]
  end

  def run_tick_loop
    queue = PushmiPullyu::PreservationQueue.new(connection: {
                                                  host: options[:redis][:host],
                                                  port: options[:redis][:port]
                                                },
                                                queue_name: options[:redis][:queue_name],
                                                age_at_least: options[:minimum_age])

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
    Daemons.run_proc(options[:process_name], dir: options[:piddir],
                                             dir_mode: :normal,
                                             monitor: options[:monitor],
                                             ARGV: @arguments) do |*_argv|

      Dir.chdir(pwd)
      start_server
    end
  end

end

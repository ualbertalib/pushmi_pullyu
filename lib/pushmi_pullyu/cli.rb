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

  def initialize
    PushmiPullyu.server_running = true # set to false by interrupt signal trap
    PushmiPullyu.reset_logger = false # set to true by SIGHUP trap
  end

  def parse(argv = ARGV)
    opts = parse_options(argv)
    opts[:daemonize] = true if COMMANDS.include? argv[0]
    opts = parse_config(opts[:config_file]).merge(opts) if opts[:config_file]

    PushmiPullyu.options = opts
  end

  def run version = ">= 0.a"
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

    setup_queue
    setup_swift

    run_tick_loop
  end

  private

  def options
    PushmiPullyu.options
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

    @parsed_opts = OptionParser.new do |o|
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

      o.on('-q', '--queue NAME', 'Name of the queue to read from') do |queue|
        opts[:queue_name] = queue
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

  def rotate_logs
    PushmiPullyu::Logging.reopen
    Daemonize.redirect_io(options[:logfile]) if options[:daemonize]
    PushmiPullyu.reset_logger = false
  end

  def run_tick_loop
    while PushmiPullyu.server_running?
      # Preservation (TODO):
      # 1. Montior queue
      # 2. Pop off GenericFile element off queue that are ready to begin process preservation event
      item = @queue.wait_next_item
      logger.debug(item)
      # 3. Retrieve GenericFile data in fedora
      # 4. creation of AIP
      # 5. bagging and tarring of AIP
      # 6. Push bag to swift API
        fileToDeposit="./examples/pushmi_pullyu.yml"
        storage.depositFile(fileToDeposit)
        logger.debug("Deposited file into the swift storage #{fileToDeposit}")
      # 7. Log successful preservation event to log files

      rotate_logs if PushmiPullyu.reset_logger?
    end
  end

  def setup_log
    if options[:daemonize]
      PushmiPullyu::Logging.initialize_logger(options[:logfile])
    else
      logger.formatter = PushmiPullyu::Logging::SimpleFormatter.new
    end
    logger.level = ::Logger::DEBUG if options[:debug]
  end

  def setup_signal_traps
    Signal.trap('INT') { shutdown }
    Signal.trap('TERM') { shutdown }
    Signal.trap('HUP') { PushmiPullyu.reset_logger = true }
  end

  def setup_queue
    @queue = PushmiPullyu::PreservationQueue.new(connection: {
                                                   host: options[:redis][:host],
                                                   port: options[:redis][:port]
                                                 },
                                                 queue_name: options[:queue_name],
                                                 age_at_least: options[:minimum_age])
  end

  def setup_swift
    @storage = PushmiPullyu::SwiftDepositer.new(connection: {
                                                   username: options[:swift][:username],
                                                   password: options[:swift][:password],
                                                   tenant:   options[:swift][:tenant],
                                                   URL:      options[:swift][:endpoint]
                                                 },
                                                 container: options[:swift][:container])
  end
  # On first call of shutdown, this will gracefully close the main run loop
  # which let's the program exit itself. Calling shutdown again will force shutdown the program
  def shutdown
    if !PushmiPullyu.server_running?
      exit!(1)
    else
      # using stderr instead of logger as it uses an underlying mutex which is not allowed inside trap contexts.
      $stderr.puts 'Exiting...  Interrupt again to force quit.'
      PushmiPullyu.server_running = false
    end
  end

  def start_server_as_daemon
    require 'daemons'

    pwd = Dir.pwd # Current directory is changed during daemonization, so store it

    opts = {
      ARGV:       @parsed_opts,
      dir:        options[:piddir],
      dir_mode:   :normal,
      monitor:    options[:monitor],
      log_output: true,
      log_dir: File.join(pwd, File.dirname(options[:logfile])),
      logfilename: File.basename(options[:logfile]),
      output_logfilename: File.basename(options[:logfile])
    }

    Daemons.run_proc(options[:process_name], opts) do |*_argv|
      Dir.chdir(pwd)
      start_server
    end
  end

end

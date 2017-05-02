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
      logger.info 'Shutting down...'
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
      Thread.new do
        logger.debug 'Received SIGHUP, reopening log file'
        PushmiPullyu::Logging.reopen
      end
    end
  end

  def parse_commands(argv)
    config.daemonize = true if COMMANDS.include? argv[0]
  end

  def parse_options(argv)
    @parsed_opts = OptionParser.new do |opts|
      opts.banner = 'Usage: pushmi_pullyu [options] [start|stop|restart|run]'
      opts.separator ''
      opts.separator 'Specific options:'

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
    @running = true # set to false by signal trap

    while @running
      sleep(5)
      logger.debug('.')
      # Preservation (TODO):
      # 1. Montior queue
      # 2. Pop off GenericFile element off queue that are ready to begin process preservation event
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

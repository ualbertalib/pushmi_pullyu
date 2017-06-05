require 'erb'
require 'fileutils'
require 'optparse'
require 'rollbar'
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

  def run
    configure_rollbar
    begin
      if options[:daemonize]
        start_server_as_daemon
      else
        # If we're running in the foreground sync the output.
        $stdout.sync = $stderr.sync = true
        start_server
      end
    # rubocop:disable Lint/RescueException
    rescue Exception => e
      Rollbar.error(e)
      raise e
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

  def configure_rollbar
    Rollbar.configure do |config|
      config.enabled = false unless options[:rollbar_token].present?
      config.access_token = options[:rollbar_token]
    end
  end

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

      o.on('-r', '--rollbar-token TOKEN', 'Enable error reporting to Rollbar') do |token|
        opts[:rollbar_token] = token if token.present?
      end

      o.on '-C', '--config PATH', 'path to YAML config file' do |config_file|
        opts[:config_file] = config_file
      end

      o.on('-L', '--logdir PATH', 'Path of directory to store logfiles') do |logdir|
        opts[:logdir] = logdir
      end

      o.on('-D', '--piddir PATH', 'Path to piddir') do |piddir|
        opts[:piddir] = piddir
      end

      o.on('-W', '--workdir PATH', 'Path where downloads, etc. are done ') do |workdir|
        opts[:workdir] = workdir
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
    Daemonize.redirect_io(PushmiPullyu.application_log_file) if options[:daemonize]
    PushmiPullyu.reset_logger = false
  end

  def run_tick_loop
    while PushmiPullyu.server_running?
      # Preservation (TODO):
      item = @queue.wait_next_item

      # add additional information about the error context to errors that occur while processing this item.
      Rollbar.scoped(noid: item) do
        begin
          # Download AIP from Fedora, bag and tar AIP directory and cleanup after block code
          PushmiPullyu::AIP.create(item) do |aip_filename|
            # Push tarred AIP to swift API
            deposited_file = @storage.deposit_file(aip_filename, options[:swift][:container])
            # Log successful preservation event to the log files
            PushmiPullyu::Logging.log_preservation_event(deposited_file)
          end
        rescue => e
          Rollbar.error(e)
          # TODO: we could re-raise here and let the daemon die on any preservation error, or just log the issue and
          # move on to the next item.
        end
      end

      rotate_logs if PushmiPullyu.reset_logger?
    end
  end

  def setup_log
    if options[:daemonize]
      PushmiPullyu::Logging.initialize_logger(PushmiPullyu.application_log_file)
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
    @storage = PushmiPullyu::SwiftDepositer.new(username: options[:swift][:username],
                                                password: options[:swift][:password],
                                                tenant: options[:swift][:tenant],
                                                endpoint: options[:swift][:endpoint],
                                                auth_version: options[:swift][:auth_version])
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
      ARGV: @parsed_opts,
      dir: options[:piddir],
      dir_mode: :normal,
      monitor: options[:monitor],
      log_output: true,
      log_dir: File.expand_path(options[:logdir]),
      logfilename: File.basename(PushmiPullyu.application_log_file),
      output_logfilename: File.basename(PushmiPullyu.application_log_file)
    }

    Daemons.run_proc(options[:process_name], opts) do |*_argv|
      Dir.chdir(pwd)
      start_server
    end
  end

end

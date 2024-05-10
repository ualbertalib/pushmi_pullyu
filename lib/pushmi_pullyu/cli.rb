require 'erb'
require 'fileutils'
require 'optparse'
require 'rollbar'
require 'singleton'
require 'yaml'
require 'json'

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
    # rubocop:enable Lint/RescueException
  end

  def start_server
    setup_signal_traps

    setup_log
    print_banner

    run_tick_loop
  end

  private

  def configure_rollbar
    Rollbar.configure do |config|
      config.enabled = false unless options[:rollbar][:token].present?
      config.access_token = options[:rollbar][:token]
      config.use_exception_level_filters_default = true
      config.exception_level_filters['IOError'] = 'ignore'
      # add a filter after Rollbar has built the error payload but before it is delivered to the API,
      # in order to strip sensitive information out of certain error messages
      exception_message_transformer = proc do |payload|
        clean_message = payload[:exception][:message].sub(/http:\/\/.+:.+@(.+)\/aip\/v1\/(.*)/,
                                                          "http://\1/aip/v1/\2")
        payload[:exception][:message] = clean_message
        payload[:message] = clean_message
      end

      config.transform << exception_message_transformer

      if options[:rollbar][:proxy_host].present?
        config.proxy = {}
        config.proxy[:host] = options[:rollbar][:proxy_host]
        config.proxy[:port] = options[:rollbar][:proxy_port] if options[:rollbar][:proxy_port].present?
        config.proxy[:user] = options[:rollbar][:proxy_user] if options[:rollbar][:proxy_user].present?
        config.proxy[:password] = options[:rollbar][:proxy_password] if options[:rollbar][:proxy_password].present?
      end
    end
  end

  def options
    PushmiPullyu.options
  end

  def parse_config(config_file)
    if File.exist?(config_file)
      YAML.safe_load(ERB.new(File.read(config_file)).result).deep_symbolize_keys || {}
    else
      {}
    end
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
        if token.present?
          opts[:rollbar] = {}
          opts[:rollbar][:token] = token
        end
      end

      o.on '-C', '--config PATH', 'Path for YAML config file' do |config_file|
        opts[:config_file] = config_file
      end

      o.on('-L', '--logdir PATH', 'Path for directory to store log files') do |logdir|
        opts[:logdir] = logdir
      end

      o.on('-D', '--piddir PATH', 'Path for directory to store pid files') do |piddir|
        opts[:piddir] = piddir
      end

      o.on('-W', '--workdir PATH', 'Path for directory where AIP creation work takes place in') do |workdir|
        opts[:workdir] = workdir
      end

      o.on('-N', '--process_name NAME', 'Name of the application process') do |process_name|
        opts[:process_name] = process_name
      end

      o.on('-m', '--monitor', 'Start monitor process for a deamon') do
        opts[:monitor] = true
      end

      o.on('-q', '--queue NAME', 'Name of the queue to read from') do |queue|
        opts[:queue_name] = queue
      end

      o.on('-i', '--ingestion_prefix PREFIX',
           'Prefix for keys used in counting the number of failed ingestion attempts') do |prefix|
        opts[:ingestion_prefix] = prefix
      end

      o.on('-x', '--ingestion_attempts NUMBER', Integer,
           'Max number of attempts to try ingesting an entity') do |ingestion_attempts|
        opts[:ingestion_attempts] = ingestion_attempts
      end

      o.on('-f', '--first_failed_wait NUMBER', Integer,
           'Time in seconds to wait after first failed deposit. Time will double every failed attempt') do |failed_wait|
        opts[:first_failed_wait] = failed_wait
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

  def run_preservation_cycle
    begin
      entity = queue.wait_next_item
      PushmiPullyu::Logging.log_preservation_attempt(entity,
                                                     queue.get_entity_ingestion_attempt(entity))
      return unless entity && entity[:type].present? && entity[:uuid].present?
    rescue StandardError => e
      log_exception(e)
    end

    # add additional information about the error context to errors that occur while processing this item.
    Rollbar.scoped(entity_uuid: entity[:uuid]) do
      # Download AIP from Jupiter, bag and tar AIP directory and cleanup after
      # block code
      PushmiPullyu::AIP.create(entity) do |aip_filename, aip_directory|
        # Push tarred AIP to swift API
        deposited_file = swift.deposit_file(aip_filename, options[:swift][:container])
        # Log successful preservation event to the log files
        PushmiPullyu::Logging.log_preservation_success(deposited_file, aip_directory)
      end
    # An EntityInvalid expection means there is a problem with the entity information format so there is no point in
    # readding it to the queue as it will always fail
    rescue PushmiPullyu::AIP::EntityInvalid => e
    rescue StandardError => e
      log_exception(e)
      begin
        queue.add_entity_in_timeframe(entity)
        PushmiPullyu::Logging.log_preservation_fail_and_retry(entity, queue.get_entity_ingestion_attempt(entity), e)
      rescue PushmiPullyu::PreservationQueue::MaxDepositAttemptsReached => e
        PushmiPullyu::Logging.log_preservation_failure(entity, queue.get_entity_ingestion_attempt(entity), e)
        log_exception(e)
      end

    # Something other than a StandardError exception means something happened which we were not expecting!
    # Make sure we log the problem
    # rubocop:disable Lint/RescueException
    rescue Exception => e
      log_exception(e)
      raise e
    end
    # rubocop:enable Lint/RescueException
  end

  def run_tick_loop
    while PushmiPullyu.server_running?
      run_preservation_cycle
      rotate_logs if PushmiPullyu.reset_logger?
    end
  end

  def setup_log
    if options[:daemonize]
      PushmiPullyu::Logging.initialize_loggers(
        log_target: PushmiPullyu.application_log_file,
        events_target: "#{PushmiPullyu.options[:logdir]}/preservation_events.log",
        json_target: "#{PushmiPullyu.options[:logdir]}/preservation_events.json"
      )
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

  def queue
    @queue ||= PushmiPullyu::PreservationQueue.new(redis_url: options[:redis][:url],
                                                   queue_name: options[:queue_name],
                                                   age_at_least: options[:minimum_age])
  end

  def swift
    @swift ||= PushmiPullyu::SwiftDepositer.new(username: options[:swift][:username],
                                                password: options[:swift][:password],
                                                tenant: options[:swift][:tenant],
                                                project_name: options[:swift][:project_name],
                                                project_domain_name: options[:swift][:project_domain_name],
                                                auth_url: options[:swift][:auth_url])
  end

  # On first call of shutdown, this will gracefully close the main run loop
  # which let's the program exit itself. Calling shutdown again will force shutdown the program
  def shutdown
    if PushmiPullyu.server_running?
      # using stderr instead of logger as it uses an underlying mutex which is not allowed inside trap contexts.
      warn 'Exiting...  Interrupt again to force quit.'
      PushmiPullyu.server_running = false
    else
      exit!(1)
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

  def log_exception(exception)
    Rollbar.error(exception)
    logger.error(exception)
  end

end

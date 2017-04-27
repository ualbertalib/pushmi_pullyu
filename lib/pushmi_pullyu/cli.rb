require 'optparse'
require 'singleton'

require 'pushmi_pullyu/logging'

# CLI runner
class PushmiPullyu::CLI

  include Singleton
  include PushmiPullyu::Logging

  attr_accessor :config

  def initialize
    self.config = PushmiPullyu::Config.new
  end

  def parse(args = ARGV)
    parse_options(args)
    # TODO
    # parse_commands
    # other setup like logging intilization
    # daemon/pidfile
    setup_log
  end

  def run
    # Trap interrupts to quit cleanly.
    Signal.trap('INT') { abort }

    print_banner

    if config.daemonize
      start_working_loop_in_daemon
    else
      # If we're running in the foreground sync the output.
      $stdout.sync = $stderr.sync = true
      start_working_loop
    end
  end

  private

  # Parse the options.
  def parse_options(argv)
    @parser ||= OptionParser.new do |opts|
      opts.banner = 'Usage: pushmi_pullyu [options]'
      opts.separator ''
      opts.separator 'Specific options:'

      opts.on('-d', '--daemonize', 'Run daemonized in the background') do
        config.daemonize = true
      end

      opts.on('-D', '--debug', 'Enable debug logging') do
        config.debug = true
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
      end.parse!(argv)
    end
  end

  def print_banner
    logger.info "Loading PushmiPullyu #{PushmiPullyu::VERSION}"
    logger.info "Running in #{RUBY_DESCRIPTION}"
  end

  def setup_log
    if config.daemonize
      PushmiPullyu::Logging.initialize_logger(config.logfile)
    else
      logger.formatter = PushmiPullyu::Logging::SimpleFormatter.new
    end
    logger.level = ::Logger::DEBUG if config.debug
  end

  def start_working_loop
    loop do
      sleep(10)
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

  def start_working_loop_in_daemon
    # TODO: Need to bring in daemons gem or something similar and wrap below logic
    start_working_loop
  end

end

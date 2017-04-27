require 'optparse'
require 'singleton'

# CLI runner
class PushmiPullyu::CLI

  include Singleton

  # Parsed options
  attr_accessor :options

  def initialize
    # Default options values
    @options = {
      debug: false,
      daemon: false
    }
  end

  def parse(args = ARGV)
    parse_options(args)
    # TODO
    # parse_commands
    # other setup like logging intilization
    # daemon/pidfile
  end

  def run
    # Trap interrupts to quit cleanly.
    Signal.trap('INT') { abort }

    if options[:daemon]
      start_working_loop_in_daemon
    else
      # If we're running in the foreground sync the output.
      $stdout.sync = $stderr.sync = true
      start_working_loop
    end
  end

  private

  def start_working_loop
    loop do
      sleep(10)

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

  # Parse the options.
  def parse_options(argv)
    @parser ||= OptionParser.new do |opts|
      opts.banner = 'Usage: pushmi_pullyu [options]'
      opts.separator ''
      opts.separator 'Specific options:'

      opts.on('-d', '--daemonize', 'Run daemonized in the background') do
        options[:daemon] = true
      end

      opts.on('-D', '--debug', 'Enable debug logging') do
        options[:debug] = true
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

end

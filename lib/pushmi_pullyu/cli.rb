require 'optparse'

# CLI runner
class PushmiPullyu::CLI

  # Parsed options
  attr_accessor :options

  def initialize(argv)
    @argv = argv

    # Default options values
    @options = {
      debug: false,
      daemon: false
    }

    parser.parse!(@argv)
  end

  # Parse the options.
  def parser
    @parser ||= OptionParser.new do |opts|
      opts.banner = 'Usage: pushmi_pullyu [options]'
      opts.separator ''
      opts.separator 'Specific options:'

      opts.on('-d', '--daemonize', 'Run daemonized in the background') do
        @options[:daemon] = true
      end

      opts.on('-D', '--debug', 'Enable debug logging') do
        @options[:debug] = true
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
    end
  end

  # Parse the current shell arguments and run the command.
  # Exits on error.
  def run!
    # Trap interrupts to quit cleanly.
    Signal.trap('INT') { abort }

    # If we're running in the foreground sync the output.
    $stdout.sync = $stderr.sync = true unless @options[:daemon]

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

end

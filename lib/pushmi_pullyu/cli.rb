module PushmiPullyu
  # CLI runner
  class CLI

    # Parsed options
    attr_accessor :options

    def initialize(argv)
      @argv = argv

      # Default options values
      @options = {
        host: 'localhost',
        port: 61_613,
        user: nil,
        password: nil,
        topic: '/topic/fedora',
        debug: false,
        reliable: true,
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

        opts.on('-o', '--host HOST', 'Set the host address of the fedora JMS server') do |host|
          @options[:host] = host
        end

        opts.on('-p', '--port PORT', 'Set the port of the fedora JMS server') do |port|
          @options[:port] = port.to_i
        end

        opts.on('-u', '--username USERNAME', 'Set the username for fedora JMS server') do |username|
          @options[:user] = username
        end

        opts.on('-w', '--password PASSWORD', 'Set the password for fedora JMS server') do |password|
          @options[:password] = password
        end

        opts.on('-t', '--topic TOPIC', 'Set the fedora JMS topic to listen on') do |topic|
          @options[:topic] = topic
        end

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


      puts "Connecting to stomp://#{@options[:host]}:#{@options[:port]}"

      client = Stomp::Client.new(@options[:user], @options[:password], @options[:host], @options[:port], @options[:reliable])

      puts "Subscripting to #{@options[:topic]}"

      client.subscribe(@options[:topic],
                       ack: 'client',
                       'activemq.prefetchSize' => 1,
                       'activemq.exclusive' => true) do |msg|

        puts "Message: #{msg}"

        # Preservation (TODO):
        # 1. Get msg, look up object in fedora...
        # 2. Determine if preservation effort is required?
        # 3. If so, get all it's information and bagit
        # 4. Push bag to swift API

        client.acknowledge(msg)
      end

      loop do
        sleep(10)
      end

      client.close
    end

  end
end

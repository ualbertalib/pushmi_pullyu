require 'spec_helper'

describe PushmiPullyu::CLI do
  let(:cli) { PushmiPullyu::CLI.instance }

  describe '#parse' do
    it 'should parse and initialize setup' do
      expect(cli).to receive(:parse_options)
      expect(cli).to receive(:parse_commands)
      cli.parse
    end
  end

  describe '#run' do
    it 'should start working loop' do
      expect(cli).to receive(:start_server)
      expect(cli).not_to receive(:start_server_as_daemon)
      cli.run
    end

    context 'should run as daemon' do
      before { cli.config.daemonize = true }

      it 'should start working loop as daemon' do
        expect(cli).to receive(:start_server_as_daemon)
        expect(cli).not_to receive(:start_server)
        cli.run
      end
    end
  end

  describe '#start_server' do
    it 'should start run tick loop' do
      expect(cli).to receive(:setup_signal_traps)
      expect(cli).to receive(:setup_log)
      expect(cli).to receive(:print_banner)
      expect(cli).to receive(:run_tick_loop)
      cli.start_server
    end
  end

  describe 'shutdown handling' do
    it 'prints a message the first time, then exits the second time' do
      allow(cli).to receive(:exit!)
      allow(cli.logger).to receive(:info)

      expect { cli.send(:shutdown) }.to change { cli.send(:running?) }.from(true).to(false)
      expect(cli.logger).to receive(:info).with('Exiting...  Interrupt again to force quit.')

      expect(cli).not_to have_received(:exit!)

      cli.send(:shutdown)

      expect(cli.logger).not_to receive(:info).with('Exiting...  Interrupt again to force quit.')
      expect(cli).to have_received(:exit!)
    end
  end

  describe '#parse_options' do
    it 'should set to debug mode' do
      cli.send(:parse_options, ['--debug'])
      expect(cli.config.debug).to be true
    end

    it 'should set logfile' do
      cli.send(:parse_options, ['--logfile', 'tmp/log/pmpy.log'])
      expect(cli.config.logfile).to be_eql 'tmp/log/pmpy.log'
    end

    it 'should set piddir' do
      cli.send(:parse_options, ['--piddir', 'dir/pids'])
      expect(cli.config.piddir).to be_eql 'dir/pids'
    end

    it 'should set process_name' do
      cli.send(:parse_options, ['--process_name', 'pmpy'])
      expect(cli.config.process_name).to be_eql 'pmpy'
    end

    it 'should set monitor' do
      cli.send(:parse_options, ['--monitor'])
      expect(cli.config.monitor).to be true
    end

    it 'should set minimum-age' do
      cli.send(:parse_options, ['--minimum-age', '900'])
      expect(cli.config.minimum_age).to eql 900.0
    end

    it 'should set redis-host' do
      cli.send(:parse_options, ['--redis-host', '192.168.77.11'])
      expect(cli.config.redis_host).to eql '192.168.77.11'
    end

    it 'should set redis-port' do
      cli.send(:parse_options, ['--redis-port', '1234'])
      expect(cli.config.redis_port).to eql 1234
    end

    it 'should set queue' do
      cli.send(:parse_options, ['--queue', 'test:pmpy:queue'])
      expect(cli.config.queue_name).to eql 'test:pmpy:queue'
    end
  end

  describe '#parse_commands' do
    it 'should set daemonize on start' do
      cli.send(:parse_commands, ['start'])
      expect(cli.config.daemonize).to be true
    end

    it 'should set daemonize on stop' do
      cli.send(:parse_commands, ['stop'])
      expect(cli.config.daemonize).to be true
    end

    it 'should set daemonize on restart' do
      cli.send(:parse_commands, ['restart'])
      expect(cli.config.daemonize).to be true
    end

    it 'should set daemonize on reload' do
      cli.send(:parse_commands, ['reload'])
      expect(cli.config.daemonize).to be true
    end

    it 'should set daemonize on run' do
      cli.send(:parse_commands, ['run'])
      expect(cli.config.daemonize).to be true
    end

    it 'should set daemonize on zap' do
      cli.send(:parse_commands, ['zap'])
      expect(cli.config.daemonize).to be true
    end

    it 'should set daemonize on status' do
      cli.send(:parse_commands, ['status'])
      expect(cli.config.daemonize).to be true
    end
  end
end

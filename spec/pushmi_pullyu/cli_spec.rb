require 'spec_helper'
require 'tempfile'

RSpec.describe PushmiPullyu::CLI do
  let(:cli) { PushmiPullyu::CLI.instance }

  describe '#run' do
    before do
      allow(cli).to receive(:start_server)
      allow(cli).to receive(:start_server_as_daemon)
    end

    it 'starts working loop' do
      cli.run

      expect(cli).to have_received(:start_server).once
      expect(cli).not_to have_received(:start_server_as_daemon)
    end

    context 'should run as daemon' do
      it 'starts working loop as daemon' do
        PushmiPullyu.options[:daemonize] = true

        cli.run

        expect(cli).to have_received(:start_server_as_daemon).once
        expect(cli).not_to have_received(:start_server)
      end
    end

    context 'Rollbar' do
      it 'sets up Rollbar' do
        PushmiPullyu.options[:rollbar][:token] = 'xyzzy'

        cli.run

        expect(Rollbar.configuration.access_token).to eq 'xyzzy'
      end
      it 'sets up Proxy for Rollbar' do
        PushmiPullyu.options[:rollbar][:proxy_host] = 'your_proxy_host_url'
        PushmiPullyu.options[:rollbar][:proxy_port] = '80'
        PushmiPullyu.options[:rollbar][:proxy_user] = 'dummy_admin'
        PushmiPullyu.options[:rollbar][:proxy_password] = 'securepassword'
        cli.run

        expect(Rollbar.configuration.proxy[:host]).to eq 'your_proxy_host_url'
        expect(Rollbar.configuration.proxy[:port]).to eq '80'
        expect(Rollbar.configuration.proxy[:user]).to eq 'dummy_admin'
        expect(Rollbar.configuration.proxy[:password]).to eq 'securepassword'
      end
    end
  end

  describe '#start_server' do
    it 'starts run tick loop' do
      allow(cli).to receive(:setup_signal_traps)
      allow(cli).to receive(:setup_log)
      allow(cli).to receive(:print_banner)
      allow(cli).to receive(:run_tick_loop)

      cli.start_server

      expect(cli).to have_received(:setup_signal_traps).once
      expect(cli).to have_received(:setup_log).once
      expect(cli).to have_received(:print_banner).once
      expect(cli).to have_received(:run_tick_loop).once
    end
  end

  describe 'shutdown handling' do
    after do
      PushmiPullyu.server_running = true
    end

    it 'prints a message the first time and exits on second time' do
      allow(cli).to receive(:exit!)
      allow(cli).to receive(:warn)

      expect { cli.send(:shutdown) }.to change { PushmiPullyu.server_running? }.from(true).to(false)
      expect(cli).not_to have_received(:exit!)
      expect(cli).to have_received(:warn).with('Exiting...  Interrupt again to force quit.').once

      cli.send(:shutdown)

      expect(cli).to have_received(:warn).with('Exiting...  Interrupt again to force quit.').once
      expect(cli).to have_received(:exit!)
    end
  end

  describe '#parse' do
    let!(:opts) { PushmiPullyu.options.dup }

    after do
      PushmiPullyu.override_options(opts)
    end

    it 'initializes setup' do
      allow(cli).to receive(:parse_options).and_return({})
      allow(cli).to receive(:parse_config)

      cli.parse

      expect(cli).to have_received(:parse_options).once
      expect(cli).not_to have_received(:parse_config)
    end

    it 'initialize setup with config yaml if given' do
      allow(cli).to receive(:parse_options).and_return(config_file: 'config/pushmi_pullyu.yml')
      allow(cli).to receive(:parse_config).and_return({})

      cli.parse

      expect(cli).to have_received(:parse_options).once
      expect(cli).to have_received(:parse_config).once
    end

    describe 'with cli options' do
      it 'sets to debug mode' do
        cli.parse(['--debug'])
        expect(PushmiPullyu.options[:debug]).to be_truthy
      end

      it 'sets up Rollbar integration' do
        cli.parse(['-r', 'asdfjkl11234eieio'])
        expect(PushmiPullyu.options[:rollbar][:token]).to eq 'asdfjkl11234eieio'
      end

      it 'sets logdir' do
        cli.parse(['-L', 'tmp/log'])
        expect(PushmiPullyu.options[:logdir]).to eq 'tmp/log'
        expect(PushmiPullyu.application_log_file).to eq 'tmp/log/pushmi_pullyu.log'
      end

      it 'sets piddir' do
        cli.parse(['-D', 'dir/pids'])
        expect(PushmiPullyu.options[:piddir]).to eq 'dir/pids'
      end

      it 'sets process_name' do
        cli.parse(['-N', 'pmpy'])
        expect(PushmiPullyu.options[:process_name]).to eq 'pmpy'
      end

      it 'sets monitor' do
        cli.parse(['-m'])
        expect(PushmiPullyu.options[:monitor]).to be_truthy
      end

      it 'sets minimum-age' do
        cli.parse(['-a', '900'])
        expect(PushmiPullyu.options[:minimum_age]).to be 900.0
      end

      it 'sets queue' do
        cli.parse(['-q', 'test:pmpy:queue'])
        expect(PushmiPullyu.options[:queue_name]).to eq 'test:pmpy:queue'
      end

      it 'sets workdir' do
        cli.parse(['-W', '/path/to/workdir'])
        expect(PushmiPullyu.options[:workdir]).to eq '/path/to/workdir'
      end
    end

    describe 'with commands' do
      it 'sets daemonize on start' do
        cli.parse(['start'])
        expect(PushmiPullyu.options[:daemonize]).to be_truthy
      end

      it 'sets daemonize on stop' do
        cli.parse(['stop'])
        expect(PushmiPullyu.options[:daemonize]).to be_truthy
      end

      it 'sets daemonize on restart' do
        cli.parse(['restart'])
        expect(PushmiPullyu.options[:daemonize]).to be_truthy
      end

      it 'sets daemonize on reload' do
        cli.parse(['reload'])
        expect(PushmiPullyu.options[:daemonize]).to be_truthy
      end

      it 'sets daemonize on run' do
        cli.parse(['run'])
        expect(PushmiPullyu.options[:daemonize]).to be_truthy
      end

      it 'sets daemonize on zap' do
        cli.parse(['zap'])
        expect(PushmiPullyu.options[:daemonize]).to be_truthy
      end

      it 'sets daemonize on status' do
        cli.parse(['status'])
        expect(PushmiPullyu.options[:daemonize]).to be_truthy
      end
    end

    describe 'config file' do
      it 'parses as expected' do
        cli.parse(['-C', 'spec/fixtures/config.yml'])

        expect(PushmiPullyu.options[:config_file]).to eq 'spec/fixtures/config.yml'
        expect(PushmiPullyu.options[:logdir]).to eq 'tmp/spec/log'
        expect(PushmiPullyu.application_log_file).to eq 'tmp/spec/log/test_pushmi_pullyu.log'
        expect(PushmiPullyu.options[:piddir]).to eq 'tmp/spec/pids'
        expect(PushmiPullyu.options[:process_name]).to eq 'test_pushmi_pullyu'
        expect(PushmiPullyu.options[:minimum_age]).to be 1
        expect(PushmiPullyu.options[:queue_name]).to eq 'test:pmpy_queue'
        expect(PushmiPullyu.options[:swift][:auth_url]).to eq 'http://example.com:8080/auth/v1.0'
        expect(PushmiPullyu.options[:rollbar][:token]).to eq 'abc123xyz'
      end

      it 'still allows command line arguments to take precedence' do
        cli.parse(['start',
                   '-C', 'spec/fixtures/config.yml',
                   '--logdir', 'path/to/random',
                   '--minimum-age', '5',
                   '--piddir', 'path/to/piddir'])

        expect(PushmiPullyu.options[:daemonize]).to be_truthy
        expect(PushmiPullyu.options[:config_file]).to eq 'spec/fixtures/config.yml'
        expect(PushmiPullyu.options[:debug]).to be_truthy
        expect(PushmiPullyu.options[:logdir]).to eq 'path/to/random'
        expect(PushmiPullyu.application_log_file).to eq 'path/to/random/test_pushmi_pullyu.log'
        expect(PushmiPullyu.options[:piddir]).to eq 'path/to/piddir'
        expect(PushmiPullyu.options[:process_name]).to eq 'test_pushmi_pullyu'
        expect(PushmiPullyu.options[:minimum_age]).to be 5.0
      end
    end

    describe 'env based config file' do
      it 'parses as expected' do
        cli.parse(['-C', 'spec/fixtures/config_with_envs.yml'])

        expect(PushmiPullyu.options[:config_file]).to eq 'spec/fixtures/config_with_envs.yml'
        expect(PushmiPullyu.options[:debug]).to be_truthy
        expect(PushmiPullyu.options[:queue_name]).to eq 'erb_test:pmpy_queue'
        expect(PushmiPullyu.options[:redis][:url]).to eq 'redis://192.168.77.11:9999'
      end
    end

    describe 'an empty config file' do
      let!(:tmp_file) { Tempfile.new('pmpy-test') }
      let!(:tmp_path) { tmp_file.path }

      before do
        # deletes the file
        tmp_file.close!
      end

      after do
        # double makes sure file is deleted
        File.unlink tmp_path if File.exist? tmp_path
      end

      it 'results in an identical options hash, except for config_file' do
        cli.parse([])
        old_options = PushmiPullyu.options.clone

        cli.parse(['-C', tmp_path])
        expect(tmp_path).to eq PushmiPullyu.options[:config_file]

        new_options = PushmiPullyu.options.clone
        expect(old_options).not_to eq new_options

        new_options.delete(:config_file)

        expect(old_options).to eq new_options
      end
    end
  end
end

require 'spec_helper'
require 'tempfile'

RSpec.describe PushmiPullyu::CLI do
  let(:cli) { described_class.instance }

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

  describe '#parse' do
    let!(:opts) { PushmiPullyu.options.dup }

    after do
      PushmiPullyu.options = opts
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

      it 'sets logfile' do
        cli.parse(['-L', 'tmp/log/pmpy.log'])
        expect(PushmiPullyu.options[:logfile]).to eq 'tmp/log/pmpy.log'
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
        expect(PushmiPullyu.options[:debug]).to be_truthy
        expect(PushmiPullyu.options[:logfile]).to eq 'tmp/pushmi_pullyu.log'
        expect(PushmiPullyu.options[:piddir]).to eq 'tmp'
        expect(PushmiPullyu.options[:process_name]).to eq 'test_pushmi_pullyu'
        expect(PushmiPullyu.options[:minimum_age]).to be 10
        expect(PushmiPullyu.options[:redis][:host]).to eq 'localhost'
        expect(PushmiPullyu.options[:redis][:port]).to be 9999
        expect(PushmiPullyu.options[:redis][:queue_name]).to eq 'test:pmpy_queue'
      end

      it 'still allows command line arguments to take precedence' do
        cli.parse(['start',
                   '-C', 'spec/fixtures/config.yml',
                   '--logfile', 'path/to/random/logfile.log',
                   '--minimum-age', '5',
                   '--piddir', 'path/to/piddir'])

        expect(PushmiPullyu.options[:daemonize]).to be_truthy
        expect(PushmiPullyu.options[:config_file]).to eq 'spec/fixtures/config.yml'
        expect(PushmiPullyu.options[:debug]).to be_truthy
        expect(PushmiPullyu.options[:logfile]).to eq 'path/to/random/logfile.log'
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
        expect(PushmiPullyu.options[:redis][:host]).to eq '192.168.77.11'
        expect(PushmiPullyu.options[:redis][:port]).to be 9999
        expect(PushmiPullyu.options[:redis][:queue_name]).to eq 'erb_test:pmpy_queue'
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

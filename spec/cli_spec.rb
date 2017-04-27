require 'spec_helper'
require 'pushmi_pullyu/cli'

describe PushmiPullyu::CLI do
  let(:cli) { PushmiPullyu::CLI.instance }

  describe '#parse' do
    it 'should parse and initialize setup' do
      expect(cli).to receive(:parse_options)
      # TODO: add more here
      cli.parse
    end
  end

  describe '#run' do
    it 'should start working loop' do
      expect(cli).to receive(:start_working_loop)
      cli.run
    end

    context 'should run as daemon' do
      before { cli.options[:daemon] = true }

      it 'should start working loop as daemon' do
        expect(cli).to receive(:start_working_loop_in_daemon)
        cli.run
      end
    end
  end

  describe '#parse_options' do
    it 'should set to debug mode' do
      cli.send(:parse_options, ['--debug'])
      expect(cli.options[:debug]).to be true
    end

    it 'should set to daemonize mode' do
      cli.send(:parse_options, ['--daemonize'])
      expect(cli.options[:daemon]).to be true
    end
  end
end

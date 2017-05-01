require 'spec_helper'

describe PushmiPullyu::Config do
  let(:config) { PushmiPullyu::Config.new }

  describe '#initialize' do
    it 'should initialize with default configuration options' do
      expect(config.daemonize).to be false
      expect(config.debug).to be false
      expect(config.logfile).to be PushmiPullyu::Config::LOGFILE
      expect(config.monitor).to be false
      expect(config.piddir).to be PushmiPullyu::Config::PIDDIR
      expect(config.process_name).to be PushmiPullyu::Config::PROCESS_NAME
    end
  end
end

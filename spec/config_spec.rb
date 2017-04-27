require 'spec_helper'

describe PushmiPullyu::Config do
  let(:config) { PushmiPullyu::Config.new }

  describe '#initialize' do
    it 'should initialize with default configuration options' do
      expect(config.daemonize).to be false
      expect(config.debug).to be false
    end
  end
end

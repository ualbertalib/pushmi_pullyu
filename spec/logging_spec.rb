require 'spec_helper'

##
# Dummy class, so that we can mix in the Logging module and test it.
#
class LoggerTest

  include PushmiPullyu::Logging

end

describe PushmiPullyu::Logging do

  it 'has a default logger' do
    expect(PushmiPullyu::Logging.logger).to be_a(Logger)
  end

  it 'allows setting of a logger' do
    new_logger = Logger.new(STDERR)
    PushmiPullyu::Logging.logger = new_logger
    expect(PushmiPullyu::Logging.logger).to eq(new_logger)
  end

  context 'when included in classes' do
    let(:dummy_class) { LoggerTest.new }

    it 'should have a logger' do
      expect(dummy_class.logger).to be_an_instance_of(Logger)
    end

    it 'should use the default logger' do
      expect(dummy_class.logger).to be PushmiPullyu::Logging.logger
    end

    it 'should allow custom loggers' do
      PushmiPullyu::Logging.logger = Logger.new(STDERR)
      expect(dummy_class.logger).to be PushmiPullyu::Logging.logger
    end

    it 'logs' do
      expect(PushmiPullyu::Logging.logger).to receive(:info).with(an_instance_of(String)).once
      dummy_class.logger.info('test')
    end
  end

end

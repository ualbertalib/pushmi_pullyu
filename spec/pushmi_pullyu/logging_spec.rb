require 'spec_helper'

##
# Dummy class, so that we can mix in the Logging module and test it.
#
class LoggerTest

  include PushmiPullyu::Logging

end

describe PushmiPullyu::Logging do
  it 'has a default logger' do
    expect(described_class.logger).to be_a(Logger)
  end

  it 'allows setting of a logger' do
    new_logger = Logger.new(STDERR)
    described_class.logger = new_logger
    expect(described_class.logger).to eq(new_logger)
  end

  context 'when included in classes' do
    let(:dummy_class) { LoggerTest.new }

    it 'has a logger' do
      expect(dummy_class.logger).to be_an_instance_of(Logger)
    end

    it 'uses the default logger' do
      expect(dummy_class.logger).to be described_class.logger
    end

    it 'allows custom loggers' do
      described_class.logger = Logger.new(STDERR)
      expect(dummy_class.logger).to be described_class.logger
    end

    it 'logs' do
      allow(described_class.logger).to receive(:info)

      dummy_class.logger.info('test')

      expect(described_class.logger).to have_received(:info).with(an_instance_of(String)).once
    end
  end
end

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

  it 'logs' do
    expect(PushmiPullyu::Logging.logger).to receive(:debug).with(an_instance_of(String)).once
    PushmiPullyu::Logging.logger.debug('test')
  end

  describe '#reopen' do
    before(:each) do
      @tmp_dir = 'tmp/test_dir'
      FileUtils.mkdir_p(@tmp_dir)
    end

    after(:each) do
      FileUtils.rm_rf(@tmp_dir)
    end

    let(:logfile) { "#{@tmp_dir}/pushmi_pullyu.log" }
    let(:logger) { PushmiPullyu::Logging.initialize_logger(logfile) }

    it 'should reopen files' do
      logger.info 'Line 1'
      FileUtils.mv(logfile, "#{logfile}.1")
      logger.info 'Line 2'
      expect(PushmiPullyu::Logging.reopen).to be(logger)
      logger.info 'Line 3'

      expect(File.read("#{logfile}.1")).to include('Line 1')
      expect(File.read("#{logfile}.1")).to include('Line 2')
      expect(File.read("#{logfile}.1")).not_to include('Line 3')
      expect(File.read(logfile)).not_to include('Line 1')
      expect(File.read(logfile)).not_to include('Line 2')
      expect(File.read(logfile)).to include('Line 3')
    end
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

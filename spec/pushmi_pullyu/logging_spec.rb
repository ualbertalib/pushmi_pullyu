require 'spec_helper'

##
# Dummy class, so that we can mix in the Logging module and test it.
#
class LoggerTest

  include PushmiPullyu::Logging

end

RSpec.describe PushmiPullyu::Logging do
  it 'has a default logger' do
    expect(described_class.logger).to be_a(Logger)
  end

  it 'allows setting of a logger' do
    new_logger = Logger.new(STDERR)
    described_class.logger = new_logger
    expect(described_class.logger).to eq(new_logger)
  end

  it 'logs' do
    allow(described_class.logger).to receive(:debug)

    described_class.logger.debug('test')

    expect(described_class.logger).to have_received(:debug).with(an_instance_of(String)).once
  end

  describe '#reopen' do
    let!(:tmp_dir) { 'tmp/test_dir' }
    let(:logfile) { "#{tmp_dir}/pushmi_pullyu.log" }
    let(:logger) { described_class.initialize_logger(logfile) }

    before do
      FileUtils.mkdir_p(tmp_dir)
    end

    after do
      FileUtils.rm_rf(tmp_dir)
    end

    it 'reopens and rotates logs' do
      logger.info 'Line 1'
      FileUtils.mv(logfile, "#{logfile}.1")
      logger.info 'Line 2'
      expect(described_class.reopen).to be(logger)
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

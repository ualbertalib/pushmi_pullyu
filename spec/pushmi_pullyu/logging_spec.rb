require 'spec_helper'
require 'time'
require 'timecop'
##
# Mock class, so that we can mix in the Logging module and test it.
#
class LoggerTest

  include PushmiPullyu::Logging

end

RSpec.describe PushmiPullyu::Logging do
  it 'has a default logger' do
    expect(PushmiPullyu::Logging.logger).to be_a(Logger)
  end

  it 'allows setting of a logger' do
    new_logger = Logger.new($stderr)
    PushmiPullyu::Logging.logger = new_logger
    expect(PushmiPullyu::Logging.logger).to eq(new_logger)
  end

  it 'logs' do
    allow(PushmiPullyu::Logging.logger).to receive(:debug)

    PushmiPullyu::Logging.logger.debug('test')

    expect(PushmiPullyu::Logging.logger).to have_received(:debug).with(an_instance_of(String)).once
  end

  describe '.reopen' do
    let(:tmp_dir) { 'tmp/test_dir' }
    let(:logfile) { "#{tmp_dir}/pushmi_pullyu.log" }
    let(:log_events) { "#{tmp_dir}/events.log" }
    let(:log_json) { "#{tmp_dir}/json.log" }
    let(:logger) do
      PushmiPullyu::Logging.initialize_loggers(log_target: logfile,
                                               events_target: log_events,
                                               json_target: log_json)
    end

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

  describe '.log_aip_activity' do
    let(:tmp_aip_dir) { 'tmp/test_aip_dir' }
    let(:tmp_log_aip_dir) { "#{tmp_aip_dir}/data/logs/" }

    before do
      FileUtils.mkdir_p(tmp_log_aip_dir)
    end

    after do
      FileUtils.rm_rf(tmp_aip_dir)
    end

    it 'logs aip activity to both aip log and application log' do
      allow(PushmiPullyu::Logging.logger).to receive(:info)

      PushmiPullyu::Logging.log_aip_activity(tmp_aip_dir, 'This is a test message')

      expect(File.exist?("#{tmp_log_aip_dir}/aipcreation.log")).to be(true)
      expect(File.read("#{tmp_log_aip_dir}/aipcreation.log")).to include('This is a test message')
      expect(PushmiPullyu::Logging.logger).to have_received(:info).with('This is a test message').once
    end
  end

  describe '.log_preservation_success' do
    let(:tmp_log_dir) { 'tmp/logs' }
    let(:tmp_aip_dir) { 'tmp/test_aip_dir' }

    before do
      FileUtils.mkdir_p(tmp_aip_dir)
      FileUtils.mkdir_p(tmp_log_dir)
      Timecop.freeze(Time.now)
    end

    after do
      FileUtils.rm_rf(tmp_aip_dir)
      FileUtils.mkdir_p(tmp_log_dir)
      Timecop.return
    end

    it 'logs preservation event to both preservation log and application log' do
      # Make sure we are initialize logger with expected file destinations and not default stdout destination
      PushmiPullyu::Logging.initialize_loggers(events_target: "#{tmp_log_dir}/preservation_events.log",
                                               json_target: "#{tmp_log_dir}/preservation_events.json")
      allow(PushmiPullyu::Logging.logger).to receive(:info)
      allow(PushmiPullyu).to receive(:options) { { logdir: tmp_log_dir } }

      # just need to replicate OpenStack::Swift::StorageObject API methods that we will be using for the logger
      deposited_file = OpenStruct.new(
        name: '9p2909328',
        last_modified: 'Fri, 02 Jun 2017 18:29:07 GMT',
        etag: '0f32868de20f3b1d4685bfa497a2c243',
        metadata: { 'project-id' => '9p2909328',
                    'aip-version' => '1.0',
                    'promise' => 'bronze',
                    'project' => 'ERA' }
      )
      entity = { uuid: 'e2ec88e3-3266-4e95-8575-8b04fac2a679', type: 'items' }

      PushmiPullyu::Logging.log_preservation_success(entity, deposited_file, tmp_aip_dir)

      # Check log
      expect(File.exist?("#{tmp_log_dir}/preservation_events.log")).to be(true)
      expect(PushmiPullyu::Logging.logger).to have_received(:info).with(an_instance_of(String)).once
      expect(
        File.read("#{tmp_log_dir}/preservation_events.log")
      ).to include("#{deposited_file.name} was successfully deposited into Swift Storage!")

      # Check JSON log
      json_data = JSON.parse(File.read("#{tmp_log_dir}/preservation_events.json").split("\n").last[/{.+}/])
      expect(json_data).to include(
        'event_type' => 'success',
        'event_time' => Time.now.to_s,
        'entity_type' => entity[:type],
        'entity_uuid' => entity[:uuid],
        'event_details' => {
          'do_uuid' => '9p2909328',
          'aip_deposited_at' => 'Fri, 02 Jun 2017 18:29:07 GMT',
          'aip_md5sum' => '0f32868de20f3b1d4685bfa497a2c243',
          'aip_sha256' => '',
          'aip_metadata' => {
            'project-id' => '9p2909328',
            'aip-version' => '1.0',
            'promise' => 'bronze',
            'project' => 'ERA'
          },
          'aip_file_details' => []
        }
      )
    end
  end

  describe '.log_preservation_attempt' do
    let(:tmp_log_dir) { 'tmp/logs' }

    before do
      FileUtils.mkdir_p(tmp_log_dir)
      # Lets freeze time to make sure timestamp checks match
      Timecop.freeze(Time.now)
    end

    after do
      FileUtils.rm_rf(tmp_log_dir)
      Timecop.return
    end

    it 'logs preservation attempts' do
      # Make sure we are initialize logger with expected file destinations and not default stdout destination
      PushmiPullyu::Logging.initialize_loggers(events_target: "#{tmp_log_dir}/preservation_events.log",
                                               json_target: "#{tmp_log_dir}/preservation_events.json")
      allow(PushmiPullyu::Logging.logger).to receive(:info)
      allow(PushmiPullyu).to receive(:options) { { logdir: tmp_log_dir } }
      # Test goes here
      entity = { uuid: 'e2ec88e3-3266-4e95-8575-8b04fac2a679', type: 'items' }
      PushmiPullyu::Logging.log_preservation_attempt(entity, 1)

      # Check log
      expect(File.exist?("#{tmp_log_dir}/preservation_events.log")).to be(true)
      log_data = File.read("#{tmp_log_dir}/preservation_events.log")
      expect(log_data).to include("#{entity[:type]} will attempt to be deposited.")
      expect(log_data).to include("#{entity[:type]} uuid: #{entity[:uuid]}	Try attempt: 2")

      # Check JSON log
      expect(File.exist?("#{tmp_log_dir}/preservation_events.json")).to be(true)
      # Get the JSON object from the log file
      json_data = JSON.parse(File.read("#{tmp_log_dir}/preservation_events.json").split("\n").last[/{.+}/])

      expect(json_data).to include(
        'event_type' => 'attempt',
        'entity_type' => 'items',
        'entity_uuid' => 'e2ec88e3-3266-4e95-8575-8b04fac2a679',
        'try_attempt' => 2,
        'event_time' => Time.now.to_s
      )
    end
  end

  describe '.log_preservation_fail_and_retry' do
    let(:tmp_log_dir) { 'tmp/logs' }

    before do
      FileUtils.mkdir_p(tmp_log_dir)
      Timecop.freeze(Time.now)
    end

    after do
      FileUtils.rm_rf(tmp_log_dir)
      Timecop.return
    end

    it 'logs preservation fail and retry' do
      # Make sure we are initialize logger with expected file destinations and not default stdout destination
      PushmiPullyu::Logging.initialize_loggers(events_target: "#{tmp_log_dir}/preservation_events.log",
                                               json_target: "#{tmp_log_dir}/preservation_events.json")
      allow(PushmiPullyu::Logging.logger).to receive(:info)
      allow(PushmiPullyu).to receive(:options) { { logdir: tmp_log_dir } }
      # Test goes here
      entity = { uuid: 'e2ec88e3-3266-4e95-8575-8b04fac2a679', type: 'items' }
      PushmiPullyu::Logging.log_preservation_fail_and_retry(
        entity,
        2,
        PushmiPullyu::AIP::Downloader::JupiterDownloadError.new
      )

      # Check log
      expect(File.exist?("#{tmp_log_dir}/preservation_events.log")).to be(true)
      log_data = File.read("#{tmp_log_dir}/preservation_events.log")
      expect(log_data).to include("#{entity[:type]} failed to be deposited and will try again.")
      expect(log_data).to include(
        "#{entity[:type]} uuid: #{entity[:uuid]}	Readding to preservation queue with try attempt: 3"
      )

      # Check JSON log
      expect(File.exist?("#{tmp_log_dir}/preservation_events.json")).to be(true)
      # Get the JSON object from the log file
      json_data = JSON.parse(File.read("#{tmp_log_dir}/preservation_events.json").split("\n").last[/{.+}/])

      expect(json_data).to include(
        'event_type' => 'fail_and_retry',
        'entity_type' => 'items',
        'entity_uuid' => 'e2ec88e3-3266-4e95-8575-8b04fac2a679',
        'try_attempt' => 3,
        'error_message' => 'PushmiPullyu::AIP::Downloader::JupiterDownloadError',
        'event_time' => Time.now.to_s
      )
    end
  end

  describe '.log_preservation_failure' do
    let(:tmp_log_dir) { 'tmp/logs' }

    before do
      FileUtils.mkdir_p(tmp_log_dir)
      Timecop.freeze(Time.now)
    end

    after do
      FileUtils.rm_rf(tmp_log_dir)
      Timecop.return
    end

    it 'logs preservation failure' do
      # Make sure we are initialize logger with expected file destinations and not default stdout destination
      PushmiPullyu::Logging.initialize_loggers(events_target: "#{tmp_log_dir}/preservation_events.log",
                                               json_target: "#{tmp_log_dir}/preservation_events.json")
      allow(PushmiPullyu::Logging.logger).to receive(:info)
      allow(PushmiPullyu).to receive(:options) { { logdir: tmp_log_dir } }
      # Test goes here
      entity = { uuid: 'e2ec88e3-3266-4e95-8575-8b04fac2a679', type: 'items' }
      PushmiPullyu::Logging.log_preservation_failure(entity,
                                                     15,
                                                     PushmiPullyu::PreservationQueue::MaxDepositAttemptsReached.new)

      # Check log
      expect(File.exist?("#{tmp_log_dir}/preservation_events.log")).to be(true)
      log_data = File.read("#{tmp_log_dir}/preservation_events.log")
      expect(log_data).to include("#{entity[:type]} failed to be deposited.")
      expect(log_data).to include("#{entity[:type]} uuid: #{entity[:uuid]}	Try attempt: 16")

      # Check JSON log
      expect(File.exist?("#{tmp_log_dir}/preservation_events.json")).to be(true)
      # Get the JSON object from the log file
      json_data = JSON.parse(File.read("#{tmp_log_dir}/preservation_events.json").split("\n").last[/{.+}/])
      expect(json_data).to include(
        'event_type' => 'failure',
        'entity_type' => 'items',
        'entity_uuid' => 'e2ec88e3-3266-4e95-8575-8b04fac2a679',
        'try_attempt' => 16,
        'error_message' => 'PushmiPullyu::PreservationQueue::MaxDepositAttemptsReached',
        'event_time' => Time.now.to_s
      )
    end
  end

  context 'when included in classes' do
    let(:mock_class) { LoggerTest.new }

    it 'has a logger' do
      expect(mock_class.logger).to be_an_instance_of(Logger)
    end

    it 'uses the default logger' do
      expect(mock_class.logger).to be PushmiPullyu::Logging.logger
    end

    it 'allows custom loggers' do
      PushmiPullyu::Logging.logger = Logger.new($stderr)
      expect(mock_class.logger).to be PushmiPullyu::Logging.logger
    end

    it 'logs' do
      allow(PushmiPullyu::Logging.logger).to receive(:info)

      mock_class.logger.info('test')

      expect(PushmiPullyu::Logging.logger).to have_received(:info).with(an_instance_of(String)).once
    end
  end
end

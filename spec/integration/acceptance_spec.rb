require 'spec_helper'
require 'json'

RSpec.describe 'Acceptance test', type: :feature do
  let(:workdir) { 'tmp/spec' }
  let(:uuid) { 'e2ec88e3-3266-4e95-8575-8b04fac2a679' }
  let(:type) { 'items' }
  let(:json_redis_input) do
    {
      uuid: uuid,
      type: type
    }
  end
  let(:aip_folder) { "#{workdir}/#{uuid}" }
  let(:aip_file) { "#{aip_folder}.tar" }
  let(:log_folder) { "#{workdir}/log" }

  let!(:opts) { PushmiPullyu.options.dup }
  let!(:redis) { Redis.new }

  before do
    # setup redis and add uuid to queue
    redis.zadd 'test:pmpy_queue', 10, json_redis_input.to_json

    FileUtils.mkdir_p(workdir)
    FileUtils.mkdir_p(log_folder)

    allow(PushmiPullyu::Logging.logger).to receive(:info)
  end

  after do
    PushmiPullyu.override_options(opts)
    redis.del 'test:pmpy_queue'
    FileUtils.rm_rf(workdir)
  end

  # this is basically testing exactly what the `PushmiPullyu::CLI#run_preservation_cycle` method does
  it 'successfully gets entity off queue, fetches data from jupiter, creates AIP and uploads to Swift' do
    cli = PushmiPullyu::CLI.instance
    cli.parse(['-C', 'spec/fixtures/config.yml', '-W', workdir])

    entity_json = JSON.parse(cli.send(:queue).wait_next_item)
    entity = {
      type: entity_json['type'],
      uuid: entity_json['uuid']
    }

    expect(entity[:uuid]).to eq uuid

    # Should not exist yet
    expect(File.exist?(aip_folder)).to be(false)
    expect(File.exist?(aip_file)).to be(false)
    expect(File.exist?("#{log_folder}/preservation_events.log")).to be(false)

    # Download data from Jupiter, bag and tar AIP directory and cleanup after block code
    VCR.use_cassette('aip_download_and_swift_upload', erb:
    {
      file_path_1: './spec/fixtures/storage/vq/hs/vqhsul2p0c9ayxzspxx19vqo05zc',
      file_path_2: './spec/fixtures/storage/qb/g4/qbg4mhpud4y7xmgjd4o3la20ggl2'
    }) do
      PushmiPullyu::AIP.create(entity) do |aip_filename|
        expect(aip_file).to eq(aip_filename)
        # aip file and folder should have been created by the creator
        expect(File.exist?(aip_folder)).to be(true)
        expect(File.exist?(aip_file)).to be(true)

        # Push tarred AIP to swift API
        deposited_file = cli.send(:swift).deposit_file(aip_filename, PushmiPullyu.options[:swift][:container])

        expect(deposited_file).to be_an_instance_of(OpenStack::Swift::StorageObject)
        expect(deposited_file.name).to eql uuid
        expect(deposited_file.container.name).to eql PushmiPullyu.options[:swift][:container]
        expect(deposited_file.metadata['project']).to eql PushmiPullyu.options[:swift][:container]
        expect(deposited_file.metadata['project-id']).to eql uuid
        expect(deposited_file.metadata['aip-version']).to eql '1.0'
        expect(deposited_file.metadata['promise']).to eql 'bronze'

        # Log successful preservation event to the log files
        PushmiPullyu::Logging.log_preservation_event(deposited_file, aip_folder)
      end
    end

    expect(File.exist?("#{log_folder}/preservation_events.log")).to be(true)
    log_details = <<~HEREDOC
      e2ec88e3-3266-4e95-8575-8b04fac2a679 was successfully deposited into Swift Storage!
      Here are the details of this preservation event:
      \tUUID: 'e2ec88e3-3266-4e95-8575-8b04fac2a679'
      \tTimestamp of Completion: 'Wed, 27 Apr 2022 23:30:50 GMT'
      \tAIP Checksum: '549aa16f0f42e7f58f4595ca09ec9ba1'
      \tMetadata: {"project-id"=>"e2ec88e3-3266-4e95-8575-8b04fac2a679", "aip-version"=>"1.0", "project"=>"ERA", "promise"=>"bronze"}
      \tFile Details:
    HEREDOC

    file_details_one = <<~HEREDOC
      \t\t{"fileset_uuid": "343c647c-6b01-4552-8643-9911da02e30b",
      \t\t"details": {
      \t\t\t"file_name": "image-sample.jpeg",
      \t\t\t"file_type": "jpeg",
      \t\t\t"file_size": 12086
      \t\t}}
    HEREDOC

    file_details_two = <<~HEREDOC
      \t\t{"fileset_uuid": "6c152bf5-3f91-4358-afa5-18a9726623be",
      \t\t"details": {
      \t\t\t"file_name": "image-sample2.jpeg",
      \t\t\t"file_type": "jpeg",
      \t\t\t"file_size": 136784
      \t\t}}
    HEREDOC

    log_file = File.read("#{log_folder}/preservation_events.log")

    expect(log_file).to include(log_details)
    expect(log_file).to include(file_details_one)
    expect(log_file).to include(file_details_two)

    # aip file and folder should have been cleaned up
    expect(File.exist?(aip_folder)).to be(false)
    expect(File.exist?(aip_file)).to be(false)
  end
end

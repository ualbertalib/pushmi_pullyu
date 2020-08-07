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
    expect(File.exist?(aip_folder)).to eq(false)
    expect(File.exist?(aip_file)).to eq(false)
    expect(File.exist?("#{log_folder}/preservation_events.log")).to eq(false)

    # Download data from Jupiter, bag and tar AIP directory and cleanup after block code
    VCR.use_cassette('aip_download_and_swift_upload', erb:
    {
      file_path_1: './spec/fixtures/storage/k7/hb/k7hb4VEsfoPXTab1W5iB6yXP',
      file_path_2: './spec/fixtures/storage/jf/KQ/jfKQSzhKRHrnfYAVY38htiZo'
    }) do
      PushmiPullyu::AIP.create(entity) do |aip_filename|
        expect(aip_file).to eq(aip_filename)
        # aip file and folder should have been created by the creator
        expect(File.exist?(aip_folder)).to eq(true)
        expect(File.exist?(aip_file)).to eq(true)

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

    expect(File.exist?("#{log_folder}/preservation_events.log")).to eq(true)
    log_details = <<~HEREDOC
      #{uuid} was successfully deposited into Swift Storage!
      Here are the details of this preservation event:
      \tUUID: '#{uuid}'
      \tTimestamp of Completion: 'Fri, 07 Aug 2020 17:24:12 GMT'
      \tAIP Checksum: '17651533f68b55fea03f5f9390211a56'
      \tMetadata: {"project-id"=>"#{uuid}", "aip-version"=>"1.0", "promise"=>"bronze", "project"=>"ERA"}
      \tFile Details:
    HEREDOC

    file_details_one = <<~HEREDOC
      \t\t{"fileset_uuid": "4dfb117e-a1af-4c16-b6c9-9c4e2ee70981",
      \t\t"details": {
      \t\t\t"file_name": "image-sample.jpeg",
      \t\t\t"file_type": "jpeg",
      \t\t\t"file_size": 12086
      \t\t}}
    HEREDOC

    file_details_two = <<~HEREDOC
      \t\t{"fileset_uuid": "5d043fa7-13b1-4367-a71b-dd13c37950bb",
      \t\t"details": {
      \t\t\t"file_name": "image-sample2.jpeg",
      \t\t\t"file_type": "jpeg",
      \t\t\t"file_size": 136784
      \t\t}}
    HEREDOC

    log_file = File.read("#{log_folder}/preservation_events.log")

    expect(log_file).to include(log_details)
    binding.pry
    expect(log_file).to include(file_details_one)
    expect(log_file).to include(file_details_two)

    # aip file and folder should have been cleaned up
    expect(File.exist?(aip_folder)).to eq(false)
    expect(File.exist?(aip_file)).to eq(false)
  end
end

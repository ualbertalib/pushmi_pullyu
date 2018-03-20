require 'spec_helper'

RSpec.describe 'Acceptance test', type: :feature do
  let(:workdir) { 'tmp/spec' }
  let(:noid) { '6841cece-41f1-4edf-ab9a-59459a127c77' }
  let(:aip_folder) { "#{workdir}/#{noid}" }
  let(:aip_file) { "#{aip_folder}.tar" }
  let(:log_folder) { "#{workdir}/log" }

  let!(:opts) { PushmiPullyu.options.dup }
  let!(:redis) { Redis.new }

  before do
    # setup redis and add noid to queue
    redis.zadd 'test:pmpy_queue', 10, noid

    FileUtils.mkdir_p(workdir)
    FileUtils.mkdir_p(log_folder)

    allow(PushmiPullyu::Logging.logger).to receive(:info)
    allow(PushmiPullyu::AIP::User)
      .to receive(:find).with(2705).and_return(OpenStruct.new(email: 'admin@example.com'))
  end

  after do
    PushmiPullyu.override_options(opts)
    redis.del 'test:pmpy_queue'
    FileUtils.rm_rf(workdir)
  end

  # this is basically testing exactly what the `PushmiPullyu::CLI#run_preservation_cycle` method does
  it 'successfully gets NOID off queue, fetches data from fedora/database, creates AIP and uploads to Swift' do
    cli = PushmiPullyu::CLI.instance
    cli.parse(['-C', 'spec/fixtures/config.yml', '-W', workdir])

    item = cli.send(:queue).wait_next_item

    expect(item).to eq noid

    # Should not exist yet
    expect(File.exist?(aip_folder)).to eq(false)
    expect(File.exist?(aip_file)).to eq(false)
    expect(File.exist?("#{log_folder}/preservation_events.log")).to eq(false)

    # Download AIP from Fedora, bag and tar AIP directory and cleanup after block code
    VCR.use_cassette('aip_download_and_swift_upload') do
      PushmiPullyu::AIP.create(item) do |aip_filename|
        expect(aip_file).to eq(aip_filename)
        # aip file and folder should have been created by the creator
        expect(File.exist?(aip_folder)).to eq(true)
        expect(File.exist?(aip_file)).to eq(true)

        # Push tarred AIP to swift API
        deposited_file = cli.send(:swift).deposit_file(aip_filename, PushmiPullyu.options[:swift][:container])

        expect(deposited_file).to be_an_instance_of(OpenStack::Swift::StorageObject)
        expect(deposited_file.name).to eql noid
        expect(deposited_file.container.name).to eql PushmiPullyu.options[:swift][:container]
        expect(deposited_file.metadata['project']).to eql PushmiPullyu.options[:swift][:container]
        expect(deposited_file.metadata['project-id']).to eql noid
        expect(deposited_file.metadata['aip-version']).to eql '1.0'
        expect(deposited_file.metadata['promise']).to eql 'bronze'

        # Log successful preservation event to the log files
        PushmiPullyu::Logging.log_preservation_event(deposited_file)
      end
    end

    expect(File.exist?("#{log_folder}/preservation_events.log")).to eq(true)
    expect(
      File.read("#{log_folder}/preservation_events.log")
    ).to include("#{noid} was successfully deposited into Swift Storage!")

    # aip file and folder should have been cleaned up
    expect(File.exist?(aip_folder)).to eq(false)
    expect(File.exist?(aip_file)).to eq(false)
  end
end

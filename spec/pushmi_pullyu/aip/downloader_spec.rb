require 'spec_helper'

RSpec.describe PushmiPullyu::AIP::Downloader do
  let(:workdir) { 'tmp/downloader_spec' }
  let(:options) do
    { workdir: workdir,
      fedora: { url: 'http://www.example.com:8080/fcrepo/rest',
                base_path: '/dev',
                user: 'fedoraAdmin',
                password: 'fedoraAdmin' },
      # This next one isn't really used, see mock of PushmiPullyu::AIP::User.find below
      database: { url: 'postgresql://jupiter:mysecretpassword@127.0.0.1/jupiter_test?pool=5' } }
  end
  let(:noid) { '6841cece-41f1-4edf-ab9a-59459a127c77' }
  let(:file_set_uuids) do
    ['01bb1b09-974d-478b-8826-2c606a447606',
     '837977d6-de61-49ea-a912-a65af5c9005e',
     '856444b6-8dd5-4dfa-857d-435e354a2ead']
  end
  let(:aip_folder) { "#{workdir}/#{noid}" }
  let(:downloader) { PushmiPullyu::AIP::Downloader.new(noid, aip_folder) }

  before do
    allow(PushmiPullyu.logger).to receive(:info)
    allow(PushmiPullyu.logger).to receive(:debug)
    allow(PushmiPullyu).to receive(:options) { options }
    FileUtils.mkdir_p(workdir)
    allow(PushmiPullyu::AIP::User)
      .to receive(:find).with(2705).and_return(OpenStruct.new(email: 'admin@example.com'))
  end

  after do
    FileUtils.rm_rf(workdir)
  end

  describe '#run' do
    it 'creates the expected structure' do
      # Should not exist yet
      expect(File.exist?(aip_folder)).to eq(false)

      VCR.use_cassette('aip_downloader_run') do
        downloader.run
      end

      # Now it exists
      expect(File.exist?(aip_folder)).to eq(true)

      # 16 folders exist
      folders =
        ["tmp/downloader_spec/#{noid}/data",
         "tmp/downloader_spec/#{noid}/data/logs",
         "tmp/downloader_spec/#{noid}/data/logs/files_logs",
         "tmp/downloader_spec/#{noid}/data/logs/files_logs/#{file_set_uuids[0]}",
         "tmp/downloader_spec/#{noid}/data/logs/files_logs/#{file_set_uuids[1]}",
         "tmp/downloader_spec/#{noid}/data/logs/files_logs/#{file_set_uuids[2]}",
         "tmp/downloader_spec/#{noid}/data/objects",
         "tmp/downloader_spec/#{noid}/data/objects/metadata",
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata",
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata/#{file_set_uuids[0]}",
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata/#{file_set_uuids[1]}",
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata/#{file_set_uuids[2]}",
         "tmp/downloader_spec/#{noid}/data/objects/files",
         "tmp/downloader_spec/#{noid}/data/objects/files/#{file_set_uuids[0]}",
         "tmp/downloader_spec/#{noid}/data/objects/files/#{file_set_uuids[1]}",
         "tmp/downloader_spec/#{noid}/data/objects/files/#{file_set_uuids[2]}"]

      folders.each do |dir|
        expect(File.exist?(dir)).to eq(true)
      end

      # 15 files exist
      files =
        ["tmp/downloader_spec/#{noid}/data/logs/aipcreation.log",
         "tmp/downloader_spec/#{noid}/data/logs/files_logs/#{file_set_uuids[0]}/content_fixity_report.n3",
         "tmp/downloader_spec/#{noid}/data/logs/files_logs/#{file_set_uuids[1]}/content_fixity_report.n3",
         "tmp/downloader_spec/#{noid}/data/logs/files_logs/#{file_set_uuids[2]}/content_fixity_report.n3",
         "tmp/downloader_spec/#{noid}/data/objects/metadata/object_metadata.n3",
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata/file_order.xml",
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata/#{file_set_uuids[0]}/file_set_metadata.n3",
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata/#{file_set_uuids[0]}/"\
         'original_file_metadata.n3',
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata/#{file_set_uuids[1]}/file_set_metadata.n3",
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata/#{file_set_uuids[1]}/"\
         'original_file_metadata.n3',
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata/#{file_set_uuids[2]}/file_set_metadata.n3",
         "tmp/downloader_spec/#{noid}/data/objects/metadata/files_metadata/#{file_set_uuids[2]}/"\
         'original_file_metadata.n3',
         "tmp/downloader_spec/#{noid}/data/objects/files/#{file_set_uuids[0]}/theses.jpg",
         "tmp/downloader_spec/#{noid}/data/objects/files/#{file_set_uuids[1]}/image-sample.jpeg",
         "tmp/downloader_spec/#{noid}/data/objects/files/#{file_set_uuids[2]}/era-logo.png"]
      files.each do |file|
        expect(File.exist?(file)).to eq(true)
      end

      # 31 files and directories total were created
      expect(Dir["tmp/downloader_spec/#{noid}/**/*"].sort).to eq((folders + files).sort)
    end
  end
end

require 'spec_helper'

RSpec.describe PushmiPullyu::AIP::Downloader do
  let(:workdir) { 'tmp/downloader_spec' }
  let(:options) do
    {
      workdir: workdir,
      jupiter: {
        user: 'ditech@ualberta.ca',
        api_key: '3eeb395e-63b7-11ea-bc55-0242ac130003',
        jupiter_url: 'http://localhost:3000/',
        aip_api_path: 'aip/v1'
      }
    }
  end
  let(:uuid) { 'f8887612-1b11-49e1-84ea-d65738fb6874' }
  let(:type) { 'items' }
  let(:entity_definition) { { uuid: uuid, type: type } }
  let(:file_set_uuids) do
    ['52e24eae-6d74-4891-b1f0-ab7e57b43909',
     '457e230d-8e34-4016-8987-08c3ab95460d']
  end
  let(:aip_folder) { "#{workdir}/#{uuid}" }
  let(:downloader) { PushmiPullyu::AIP::Downloader.new(entity_definition, aip_folder) }
  let(:folders) do
    [
      "tmp/downloader_spec/#{uuid}/data",
      "tmp/downloader_spec/#{uuid}/data/logs",
      "tmp/downloader_spec/#{uuid}/data/logs/files_logs",
      "tmp/downloader_spec/#{uuid}/data/logs/files_logs/#{file_set_uuids[0]}",
      "tmp/downloader_spec/#{uuid}/data/logs/files_logs/#{file_set_uuids[1]}",
      "tmp/downloader_spec/#{uuid}/data/objects",
      "tmp/downloader_spec/#{uuid}/data/objects/metadata",
      "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata",
      "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata/#{file_set_uuids[0]}",
      "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata/#{file_set_uuids[1]}",
      "tmp/downloader_spec/#{uuid}/data/objects/files",
      "tmp/downloader_spec/#{uuid}/data/objects/files/#{file_set_uuids[0]}",
      "tmp/downloader_spec/#{uuid}/data/objects/files/#{file_set_uuids[1]}"
    ]
  end
  let(:files_copied) do
    [
      "tmp/downloader_spec/#{uuid}/data/objects/files/#{file_set_uuids[0]}/image-sample.jpeg",
      "tmp/downloader_spec/#{uuid}/data/objects/files/#{file_set_uuids[1]}/theses.jpg"
    ]
  end
  let(:files_downloaded) do
    [
      # aipcreation.log is not downladed but it makes sense to add it here
      "tmp/downloader_spec/#{uuid}/data/logs/aipcreation.log",
      "tmp/downloader_spec/#{uuid}/data/logs/files_logs/#{file_set_uuids[0]}/content_fixity_report.n3",
      "tmp/downloader_spec/#{uuid}/data/logs/files_logs/#{file_set_uuids[1]}/content_fixity_report.n3",
      "tmp/downloader_spec/#{uuid}/data/objects/metadata/object_metadata.n3",
      "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata/file_order.xml",
      "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata/#{file_set_uuids[0]}/file_set_metadata.n3",
      "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata/#{file_set_uuids[0]}/"\
      'original_file_metadata.n3',
      "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata/#{file_set_uuids[1]}/file_set_metadata.n3",
      "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata/#{file_set_uuids[1]}/"\
      'original_file_metadata.n3'
    ]
  end
  let(:aip_downloader_run_arguments) do
    {
      file_path_1: './spec/fixtures/storage/k7/hb/k7hb4VEsfoPXTab1W5iB6yXP',
      file_path_2: './spec/fixtures/storage/jf/KQ/jfKQSzhKRHrnfYAVY38htiZo'
    }
  end

  before do
    allow(PushmiPullyu.logger).to receive(:info)
    allow(PushmiPullyu.logger).to receive(:debug)
    allow(PushmiPullyu).to receive(:options) { options }
    FileUtils.mkdir_p(workdir)
  end

  after do
    FileUtils.rm_rf(workdir)
  end

  describe '#run' do
    it 'copies the correct files' do
      VCR.use_cassette('aip_downloader_run', erb: aip_downloader_run_arguments) do
        downloader.run
      end
      folders_content = Dir["tmp/downloader_spec/#{uuid}/data/objects/files/*/*"].sort
      expect(folders_content).to eq(files_copied.sort)
    end

    it 'downloads the correct files' do
      VCR.use_cassette('aip_downloader_run', erb: aip_downloader_run_arguments) do
        downloader.run
      end

      folders_content = Dir[
        "tmp/downloader_spec/#{uuid}/data/logs/aipcreation.log",
        "tmp/downloader_spec/#{uuid}/data/logs/files_logs/*/content_fixity_report.n3",
        "tmp/downloader_spec/#{uuid}/data/objects/metadata/object_metadata.n3",
        "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata/file_order.xml",
        "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata/*/file_set_metadata.n3",
        "tmp/downloader_spec/#{uuid}/data/objects/metadata/files_metadata/*/"\
        'original_file_metadata.n3',
      ]

      expect(folders_content.sort).to eq(files_downloaded.sort)
    end

    it 'creates the expected structure' do
      # Should not exist yet
      expect(File.exist?(aip_folder)).to eq(false)

      VCR.use_cassette('aip_downloader_run', erb: aip_downloader_run_arguments) do
        downloader.run
      end

      # Now it exists
      expect(File.exist?(aip_folder)).to eq(true)

      # 13 folders exist
      folders.each do |dir|
        expect(File.exist?(dir)).to eq(true)
      end

      # 11 files exist
      files = files_copied + files_downloaded
      files.each do |file|
        expect(File.exist?(file)).to eq(true)
      end

      # 24 files and directories total were created
      expect(Dir["tmp/downloader_spec/#{uuid}/**/*"].sort).to eq((folders + files).sort)
    end
  end
end

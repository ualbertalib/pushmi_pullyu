require 'spec_helper'

RSpec.describe PushmiPullyu::AipDownloader do
  let(:options) do
    { workdir: '/tmp/whatever' }
  end
  let(:noid) { 'abc123whatever' }
  let(:aip_downloader) { described_class.new(noid, options) }
  let(:basedir) { "#{options[:workdir]}/#{noid}" }

  describe '#initialize' do
    it 'sets the download directories properly' do
      expect(aip_downloader.basedir)
        .to eq('/tmp/whatever/abc123whatever')
      expect(aip_downloader.datadir)
        .to eq('/tmp/whatever/abc123whatever/data')
      expect(aip_downloader.objectsdir)
        .to eq('/tmp/whatever/abc123whatever/data/objects')
      expect(aip_downloader.metadatadir)
        .to eq('/tmp/whatever/abc123whatever/data/objects/metadata')
      expect(aip_downloader.logsdir)
        .to eq('/tmp/whatever/abc123whatever/data/logs')
      expect(aip_downloader.thumbnailsdir)
        .to eq('/tmp/whatever/abc123whatever/data/thumbnails')
    end
  end

  describe '#make_object_directories' do
    it 'creates the directories needed for the AIP' do
      allow(FileUtils).to receive(:mkdir_p)
      aip_downloader.make_object_directories
      expect(FileUtils)
        .to have_received(:mkdir_p).with('/tmp/whatever/abc123whatever')
      expect(FileUtils)
        .to have_received(:mkdir_p).with('/tmp/whatever/abc123whatever/data')
      expect(FileUtils)
        .to have_received(:mkdir_p).with('/tmp/whatever/abc123whatever/data/objects')
      expect(FileUtils)
        .to have_received(:mkdir_p).with('/tmp/whatever/abc123whatever/data/objects/metadata')
      expect(FileUtils)
        .to have_received(:mkdir_p).with('/tmp/whatever/abc123whatever/data/logs')
      expect(FileUtils)
        .to have_received(:mkdir_p).with('/tmp/whatever/abc123whatever/data/thumbnails')
      expect(FileUtils).to have_received(:mkdir_p).exactly(6).times
    end
  end

  it 'downloads the main object' do
    download_args = { download_path: aip_downloader.main_object_filename }
    allow(aip_downloader).to receive(:aip_logger)
    allow(aip_downloader.aip_logger).to receive(:info)
    allow(aip_downloader.fetcher).to receive(:download_rdf_object)
    aip_downloader.download_main_object
    expect(aip_downloader.fetcher)
      .to have_received(:download_rdf_object).with(download_args)
  end
end

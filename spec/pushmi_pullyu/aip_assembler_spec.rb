require 'spec_helper'

RSpec.describe PushmiPullyu::AipAssembler do
  let(:options) do
    { workdir: '/tmp/whatever' }
  end
  let(:noid) { 'abc123whatever' }
  let(:aip_assembler) { described_class.new(noid, options) }
  let(:basedir) { "#{options[:workdir]}/#{noid}" }

  describe '#initialize' do
    it 'sets the download directories properly' do
      expect(aip_assembler.basedir).to eq(basedir)
      expect(aip_assembler.objectsdir).to eq("#{basedir}/objects")
      expect(aip_assembler.metadatadir).to eq("#{basedir}/objects/metadata")
      expect(aip_assembler.logsdir).to eq("#{basedir}/logs")
      expect(aip_assembler.thumbnailsdir).to eq("#{basedir}/thumbnails")
    end
  end

  describe '#make_object_directories' do
    it 'creates the directories needed for the AIP' do
      allow(FileUtils).to receive(:mkdir_p)
      aip_assembler.make_object_directories
      expect(FileUtils).to have_received(:mkdir_p).with(aip_assembler.basedir)
      expect(FileUtils).to have_received(:mkdir_p).with(aip_assembler.objectsdir)
      expect(FileUtils).to have_received(:mkdir_p).with(aip_assembler.metadatadir)
      expect(FileUtils).to have_received(:mkdir_p).with(aip_assembler.logsdir)
      expect(FileUtils).to have_received(:mkdir_p).with(aip_assembler.thumbnailsdir)
      expect(FileUtils).to have_received(:mkdir_p).exactly(5).times
    end
  end

  it 'downloads the main object' do
    download_args = { download_path: aip_assembler.main_object_filename }
    allow(aip_assembler.fetcher).to receive(:download_rdf_object)
    aip_assembler.download_main_object
    expect(aip_assembler.fetcher)
      .to have_received(:download_rdf_object).with(download_args)
  end
end

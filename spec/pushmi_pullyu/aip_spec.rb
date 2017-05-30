require 'spec_helper'

RSpec.describe PushmiPullyu::AIP do
  let(:noid) { '9p2909328' }
  let(:workdir) { 'tmp/aip_spec' }
  let(:aip_folder) { "#{workdir}/#{noid}" }
  let(:aip_file) { "#{aip_folder}.tar" }

  before do
    allow(PushmiPullyu).to receive(:options) { { workdir: workdir } }
  end

  describe '.create' do
    it 'calls aip creator class and returns the tar filename' do
      creator = instance_double(PushmiPullyu::AIP::Creator)
      allow(PushmiPullyu::AIP::Creator).to receive(:new).and_return(creator)
      allow(creator).to receive(:run)

      filename = PushmiPullyu::AIP.create(noid)

      expect(creator).to have_received(:run).once
      expect(filename).to eq(File.expand_path(aip_file))
    end
  end

  describe '.download' do
    it 'calls aip downloader class and returns the aip directory' do
      downloader = instance_double(PushmiPullyu::AIP::Downloader)
      allow(PushmiPullyu::AIP::Downloader).to receive(:new).and_return(downloader)
      allow(downloader).to receive(:run)

      aip_directory = PushmiPullyu::AIP.download(noid)

      expect(downloader).to have_received(:run).once
      expect(aip_directory).to eq(File.expand_path(aip_folder))
    end
  end

  describe '.destroy' do
    it 'calls rm on AIP directory and AIP file' do
      # create the work folder/aip tar file
      FileUtils.mkdir_p(aip_folder)
      FileUtils.touch(aip_file)

      PushmiPullyu::AIP.destroy(noid)

      # Work directory has been removed
      expect(File.exist?(aip_folder)).to eq(false)
      # AIP tar file has been removed
      expect(File.exist?(aip_file)).to eq(false)

      # cleanup workdir
      FileUtils.rm_rf(workdir)
    end
  end

  describe '.aip_filename' do
    it 'returns the AIP filename' do
      expect(PushmiPullyu::AIP.aip_filename(noid)).to eq(File.expand_path(aip_file))
    end
  end

  describe '.aip_directory' do
    it 'returns the AIP directory' do
      expect(PushmiPullyu::AIP.aip_directory(noid)).to eq(File.expand_path(aip_folder))
    end
  end

  describe '.validate_noid' do
    it 'validates the noid' do
      expect { PushmiPullyu::AIP.validate_noid(noid) }.not_to raise_error
      expect { PushmiPullyu::AIP.validate_noid('') }.to raise_error(PushmiPullyu::AIP::NoidInvalid)
    end
  end
end

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
    it 'validates the noid and raises exception if not valid' do
      expect { PushmiPullyu::AIP.create('') }.to raise_error(PushmiPullyu::AIP::NoidInvalid)
      expect { PushmiPullyu::AIP.create('9p29/9328') }.to raise_error(PushmiPullyu::AIP::NoidInvalid)
    end

    it 'calls aip downloader and creator class and cleans up aip folder and file' do
      # create the work folder/aip tar file
      FileUtils.mkdir_p(aip_folder)
      FileUtils.touch(aip_file)

      # stub out creator/downloader classes
      creator = instance_double(PushmiPullyu::AIP::Creator)
      allow(PushmiPullyu::AIP::Creator).to receive(:new).and_return(creator)
      allow(creator).to receive(:run)

      downloader = instance_double(PushmiPullyu::AIP::Downloader)
      allow(PushmiPullyu::AIP::Downloader).to receive(:new).and_return(downloader)
      allow(downloader).to receive(:run)

      PushmiPullyu::AIP.create(noid) do |filename|
        expect(filename).to eq(aip_file)
      end

      expect(creator).to have_received(:run).once
      expect(downloader).to have_received(:run).once

      # Work directory has been removed
      expect(File.exist?(aip_folder)).to eq(false)
      # AIP tar file has been removed
      expect(File.exist?(aip_file)).to eq(false)
      # cleanup workdir
      FileUtils.rm_rf(workdir)
    end
  end
end

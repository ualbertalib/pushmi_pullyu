require 'spec_helper'

RSpec.describe PushmiPullyu::AIP do
  let(:uuid) { '46e32482-9bb0-4bcb-aef0-f87f574249c3' }
  let(:type) { 'items' }
  let(:workdir) { 'tmp/aip_spec' }
  let(:aip_folder) { "#{workdir}/#{uuid}" }
  let(:aip_file) { "#{aip_folder}.tar" }

  before do
    allow(PushmiPullyu).to receive(:options) { { workdir: workdir } }
  end

  describe '.create' do
    it 'validates the uuid and raises exception if not valid' do
      expect do
        PushmiPullyu::AIP.create(nil)
      end.to raise_error(PushmiPullyu::AIP::EntityInvalid)

      expect do
        PushmiPullyu::AIP.create(uuid: '', type: type)
      end.to raise_error(PushmiPullyu::AIP::EntityInvalid)

      expect do
        PushmiPullyu::AIP.create(uuid: uuid, type: '')
      end.to raise_error(PushmiPullyu::AIP::EntityInvalid)
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

      PushmiPullyu::AIP.create(uuid: uuid, type: type) do |filename|
        expect(filename).to eq(aip_file)
      end

      expect(creator).to have_received(:run).once
      expect(downloader).to have_received(:run).once

      # Work directory has been removed
      expect(File.exist?(aip_folder)).to be(false)
      # AIP tar file has been removed
      expect(File.exist?(aip_file)).to be(false)
      # cleanup workdir
      FileUtils.rm_rf(workdir)
    end
  end
end

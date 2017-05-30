require 'spec_helper'

# Please note that much of the nitty-gritty is tested in the specs for creator and downloader

RSpec.describe PushmiPullyu::AIP do
  let(:workdir) { 'tmp/aip_spec' }
  let(:noid) { '9p2909328' }
  let(:mock_download_data) { "spec/fixtures/aip_download/#{noid}" }
  let(:aip_file) { "#{workdir}/#{noid}.tar" }
  let(:aip_folder) { "#{workdir}/#{noid}" }

  before do
    allow(PushmiPullyu).to receive(:options) { { workdir: workdir } }
    FileUtils.mkdir_p(workdir)
    FileUtils.cp_r(mock_download_data, workdir)
  end

  after do
    FileUtils.rm_rf(workdir)
    FileUtils.rm_rf(aip_file)
  end

  describe '.create' do
    it 'creates the aip, removes work directory by default' do
      # Mocked download data should exist
      expect(File.exist?(aip_folder)).to eq(true)

      # Should not exist yet
      expect(File.exist?(aip_file)).to eq(false)

      filename = PushmiPullyu::AIP.create(noid)

      # Work directory is not removed
      expect(File.exist?(aip_folder)).to eq(true)
      # AIP exists
      expect(File.exist?(aip_file)).to eq(true)
      expect(filename).to eq(File.expand_path(aip_file))
    end
  end
end

require 'spec_helper'

# Please note that much of the nitty-gritty is tested in the specs for creator and downloader

RSpec.describe PushmiPullyu::AIP do
  let(:workdir) { 'tmp/aip_spec' }
  let(:options) do
    { workdir: workdir,
      fedora: { url: 'http://www.example.com:8983/fedora/rest',
                base_path: '/dev',
                user: 'fedoraAdmin',
                password: 'fedoraAdmin' },
      solr: { url: 'http://www.example.com:8983/solr/development' } }
  end
  let(:noid) { '9p2909328' }
  let(:aip_file) { "#{workdir}/#{noid}.tar" }

  before do
    allow(PushmiPullyu.logger).to receive(:info)
    allow(PushmiPullyu.logger).to receive(:debug)
    allow(PushmiPullyu).to receive(:options) { options }
    FileUtils.mkdir_p(workdir)
  end

  after do
    FileUtils.rm_rf(workdir)
    FileUtils.rm_rf(aip_file)
  end

  describe '#create' do
    it 'creates the aip, removes work directory by default' do
      VCR.use_cassette('aip_downloader_run') do
        # Should not exist yet
        expect(File.exist?('tmp/aip_spec/9p2909328')).to eq(false)
        expect(File.exist?('tmp/aip_spec/9p2909328.tar')).to eq(false)

        filename = PushmiPullyu::AIP.create(noid)

        # Work directory is removed
        expect(File.exist?('tmp/aip_spec/9p2909328')).to eq(false)
        # AIP exists
        expect(File.exist?('tmp/aip_spec/9p2909328.tar')).to eq(true)
        expect(filename).to eq(File.expand_path('tmp/aip_spec/9p2909328.tar'))
      end
    end

    it 'creates the AIP, can keep the AIP directory' do
      VCR.use_cassette('aip_downloader_run') do
        # Should not exist yet
        expect(File.exist?('tmp/aip_spec/9p2909328')).to eq(false)
        expect(File.exist?('tmp/aip_spec/9p2909328.tar')).to eq(false)

        PushmiPullyu::AIP.create(noid, should_clean_work_directories: false)

        # Work directory is NOT removed
        expect(File.exist?('tmp/aip_spec/9p2909328')).to eq(true)
        # AIP exists
        expect(File.exist?('tmp/aip_spec/9p2909328.tar')).to eq(true)
      end
    end
  end
end

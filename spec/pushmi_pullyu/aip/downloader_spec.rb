require 'spec_helper'

RSpec.describe PushmiPullyu::AIP::Downloader do
  let(:workdir) { 'tmp/downloader_spec' }
  let(:options) do
    { workdir: workdir,
      fedora: { url: 'http://www.example.com:8983/fedora/rest',
                base_path: '/dev',
                user: 'fedoraAdmin',
                password: 'fedoraAdmin' },
      solr: { url: 'http://www.example.com:8983/solr/development' } }
  end
  let(:noid) { '9p2909328' }
  let(:downloader) { described_class.new(noid) }

  before do
    allow(PushmiPullyu.logger).to receive(:info)
    allow(PushmiPullyu).to receive(:options) { options }
    FileUtils.mkdir_p(workdir)
  end

  after do
    FileUtils.rm_rf(workdir)
  end

  describe '#run' do
    it 'creates the expected structure' do
      VCR.use_cassette('aip_downloader_run') do
        expect(File.exist?("#{workdir}/#{noid}")).to eq(false)
        downloader.run
        expect(File.exist?("#{workdir}/#{noid}")).to eq(true)
        # Add specs for other files here ...
      end
    end
  end
end

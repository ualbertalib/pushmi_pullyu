require 'spec_helper'

RSpec.describe PushmiPullyu::AIP::FedoraFetcher do
  let(:noid) { 'abc123whatever' }
  let(:fedora_fetcher) { PushmiPullyu::AIP::FedoraFetcher.new(noid) }
  let(:fedora_fetcher_404) { PushmiPullyu::AIP::FedoraFetcher.new('ohnoimbad') }
  let(:workdir) { 'tmp/downloader_spec' }
  let(:download_path) { "#{workdir}/newobject.n3" }

  before do
    FileUtils.mkdir_p(workdir)
    allow(PushmiPullyu).to receive(:options) {
      { fedora: { url: 'http://www.example.com:8983/fedora/rest',
                  base_path: '/test',
                  user: 'gollum',
                  password: 'iH8zH0bb1tzeZ' } }
    }
  end

  after do
    FileUtils.rm_rf(workdir)
  end

  describe '#object_url' do
    it 'sets the object URL correctly' do
      expect(fedora_fetcher.object_url)
        .to eq('http://www.example.com:8983/fedora/rest/test/ab/c1/23/wh/abc123whatever')
    end
  end

  describe '#download_object' do
    it 'gets an object with a correct noid and creates the file' do
      VCR.use_cassette('fedora_fetcher_200') do
        expect(fedora_fetcher.download_object(download_path)).to eq(true)
        expect(File.exist?(download_path)).to eq(true)
      end
    end

    it 'raises an error on an object with a bad noid' do
      VCR.use_cassette('fedora_fetcher_404') do
        expect { fedora_fetcher_404.download_object(download_path) }
          .to raise_error(PushmiPullyu::AIP::FedoraFetcher::FedoraFetchError)
      end
    end

    it 'can return false for an object with a bad noid' do
      VCR.use_cassette('fedora_fetcher_404') do
        expect(fedora_fetcher_404.download_object(download_path, optional: true)).to eq(false)
      end
    end
  end
end

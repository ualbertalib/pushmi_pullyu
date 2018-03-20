require 'spec_helper'

RSpec.describe PushmiPullyu::AIP::FedoraFetcher do
  let(:noid) { 'abc123whatever' }
  let(:fedora_fetcher) { PushmiPullyu::AIP::FedoraFetcher.new(noid) }
  let(:fedora_fetcher_404) { PushmiPullyu::AIP::FedoraFetcher.new('ohnoimbad') }
  let(:workdir) { 'tmp/downloader_spec' }
  let(:download_path) { "#{workdir}/newobject.n3" }

  before do
    FileUtils.mkdir_p(workdir)
    allow(PushmiPullyu).to receive(:options).and_return(
      fedora: { url: 'http://www.example.com:8080/fcrepo/rest',
                base_path: '/test',
                user: 'gollum',
                password: 'iH8zH0bb1tzeZ' },
      # This next one isn't really used, see mock of PushmiPullyu::AIP::User.find below
      database: { url: 'postgresql://jupiter:mysecretpassword@127.0.0.1/jupiter_test?pool=5' }
    )
  end

  after do
    FileUtils.rm_rf(workdir)
  end

  describe '#object_url' do
    it 'sets the object URL correctly' do
      expect(fedora_fetcher.object_url)
        .to eq('http://www.example.com:8080/fcrepo/rest/test/ab/c1/23/wh/abc123whatever')
    end
  end

  describe '#download_object' do
    it 'gets an object with a correct noid and creates the file' do
      VCR.use_cassette('fedora_fetcher_200') do
        expect(fedora_fetcher.download_object(download_path)).to eq(true)
      end

      expect(File.exist?(download_path)).to eq(true)
    end

    it "doesn't change owners by default" do
      VCR.use_cassette('fedora_fetcher_owner') do
        expect(fedora_fetcher.download_object(download_path)).to eq(true)
      end
      graph = RDF::Graph.load(download_path)
      owner = nil
      graph.query(predicate: RDF::URI('http://purl.org/ontology/bibo/owner')) do |statement|
        owner = statement.object
      end
      expect(owner.to_i).to eq(2705)
    end

    it 'changes owners as an option' do
      allow(PushmiPullyu::AIP::User)
        .to receive(:find).with(2705).and_return(OpenStruct.new(email: 'admin@example.com'))

      VCR.use_cassette('fedora_fetcher_owner') do
        expect(fedora_fetcher.download_object(download_path, should_add_user_email: true)).to eq(true)
      end
      graph = RDF::Graph.load(download_path)
      owner = nil
      graph.query(predicate: RDF::URI('http://purl.org/ontology/bibo/owner')) do |statement|
        owner = statement.object
      end
      expect(owner.to_s).to eq('admin@example.com')
    end

    it "raises an error if the owner can't be fetched" do
      allow(PushmiPullyu::AIP::User)
        .to receive(:find).with(2705).and_raise(ActiveRecord::RecordNotFound)

      VCR.use_cassette('fedora_fetcher_owner') do
        expect { fedora_fetcher.download_object(download_path, should_add_user_email: true) }
          .to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it 'raises an error if no owner is found' do
      # cassette fedora_fetcher_200 has no owner predicate
      VCR.use_cassette('fedora_fetcher_200') do
        expect { fedora_fetcher.download_object(download_path, should_add_user_email: true) }
          .to raise_error(PushmiPullyu::AIP::FedoraFetcher::NoOwnerPredicate)
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

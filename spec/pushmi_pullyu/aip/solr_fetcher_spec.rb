require 'spec_helper'

RSpec.describe PushmiPullyu::AIP::SolrFetcher do
  let(:noid) { '9p2909328' }
  let(:solr_fetcher) { PushmiPullyu::AIP::SolrFetcher.new(noid) }
  let(:solr_fetcher_404) { PushmiPullyu::AIP::SolrFetcher.new('ohnoimbad') }

  before do
    allow(PushmiPullyu).to receive(:options) {
      { solr: { url: 'http://www.example.com:8983/solr/development' } }
    }
  end

  describe '#fetch_permission_object_ids' do
    it 'gets a permission object with a correct noid' do
      VCR.use_cassette('solr_fetcher_200') do
        permission_objects = solr_fetcher.fetch_permission_object_ids

        expect(permission_objects).to be_an_instance_of(Array)
        expect(permission_objects.count).to eq(3)
      end
    end

    it 'raises an error on a permission object with a bad noid' do
      VCR.use_cassette('solr_fetcher_404') do
        expect { solr_fetcher_404.fetch_permission_object_ids }
          .to raise_error(PushmiPullyu::AIP::SolrFetcher::SolrFetchError)
      end
    end
  end
end

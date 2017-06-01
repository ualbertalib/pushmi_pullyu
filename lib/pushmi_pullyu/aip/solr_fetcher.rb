require 'json'
require 'net/http'

class PushmiPullyu::AIP::SolrFetcher

  class SolrFetchError < StandardError; end

  def initialize(noid)
    @noid = noid
  end

  def fetch_permission_object_ids
    hash = JSON.parse(run_query_json)

    return [] if hash['response']['docs'].empty?

    hash['response']['docs'].map { |hit| hit['id'] }
  end

  private

  # Return fetched results, else raise an error
  def run_query_json
    response = Net::HTTP.get_response(
      URI("#{PushmiPullyu.options[:solr][:url]}/select?q=accessTo_ssim:#{@noid}&fl=id&wt=json")
    )

    return response.body if response.is_a?(Net::HTTPSuccess)

    raise SolrFetchError
  end

end

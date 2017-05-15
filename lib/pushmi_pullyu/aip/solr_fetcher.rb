require 'pushmi_pullyu'
require 'net/http'
require 'json'

class PushmiPullyu::SolrFetcher

  def self.get_permission_object_ids(noid)
    # Return array of ids
    new.get_permisson_object_ids(noid)
  end

  def get_permission_object_ids(noid)
    json = fetch_query_array("accessTo_ssim:#{noid}", fields: 'id', url_extra: nil)
    hash = JSON.parse(json)
    return [] if hash['response']['docs'].empty?
    hash['response']['docs'].values
  end

  private

  def solr_url
    PushmiPullyu.options[:solr][:url]
  end

  def query_url
    "#{solr_url}/select"
  end

  def run_query_json(query, fields: nil, url_extra: nil)
    # Return fetched results, else raise an error
    url = "#{query_url}?q=#{query}"
    url += "&fl=#{fields}" if fields
    url += '&wt=json'
    url += url_extra if url_extra
    uri = URI(url)

    request = Net::HTTP::Get.new(uri)

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    return response.body if response.is_a?(Net::HTTPSuccess)

    raise PushmiPullyu::Aip::SolrFetchError
  end

end

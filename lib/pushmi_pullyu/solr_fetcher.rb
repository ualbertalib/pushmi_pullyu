require 'net/http'
require 'csv'

# Any error (except possibly 404, see below)
class PushmiPullyu::SolrError < StandardError; end

class PushmiPullyu::SolrFetcher

  attr_accessor :config

  def initialize(config = nil)
    self.config = config || PushmiPullyu.options
  end

  def query_url
    "#{config[:solr][:url]}/select"
  end

  def run_query(query, fields: nil, csv: false, url_extra: nil)
    # Return fetched results, else raise an error
    url = "#{query_url}?q=#{query}"
    url += "&fl=#{fields}" if fields
    url += '&wt=csv' if csv
    url += url_extra if url_extra
    uri = URI(url)

    request = Net::HTTP::Get.new(uri)

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    return response.body if response.is_a?(Net::HTTPSuccess)

    raise PushmiPullyu::SolrError
  end

  # Return output as an array of hashes
  def fetch_query_array(query, fields: nil, url_extra: nil)
    out = run_query(query, fields: fields, url_extra: url_extra, csv: true)
    results = []
    header = nil
    CSV.parse(out) do |row|
      if header.nil?
        header = row
        next
      end
      hash = {}
      row.each_with_index do |value, index|
        hash[header[index]] = value
      end
      results << hash
    end
    results
  end

end

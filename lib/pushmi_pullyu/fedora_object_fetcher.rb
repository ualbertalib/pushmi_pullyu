require 'pushmi_pullyu'
require 'net/http'
require 'fileutils'

class PushmiPullyu::FedoraObjectFetcher

  attr_accessor :config, :noid

  RDF_FORMAT = 'text/rdf+n3'.freeze

  def initialize(noid, config = nil)
    self.noid = noid
    self.config = config || PushmiPullyu.options
  end

  def object_url
    "#{config[:fedora][:url]}#{config[:fedora][:base_path]}/#{pairtree}"
  end

  def pairtree
    "#{noid[0..1]}/#{noid[2..3]}/#{noid[4..5]}/#{noid[6..7]}/#{noid}"
  end

  def download_object(download_path: nil, url_extra: nil,
                      return_false_on_404: false, rdf: false)
    # Return true on success, raise an error otherwise (see return_false_on_404 option)
    url = object_url
    url += url_extra if url_extra
    uri = URI(url)

    request = Net::HTTP::Get.new(uri)
    request.basic_auth(config[:fedora][:user], config[:fedora][:password])

    request['Accept'] = RDF_FORMAT if rdf

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      if response.is_a?(Net::HTTPNotFound)
        raise PushmiPullyu::FedoraFetchError unless return_false_on_404
        return false
      end
      raise PushmiPullyu::FedoraFetchError
    end

    if download_path
      file = File.open(download_path, 'wb')
      file.write(response.body)
      file.close
    else
      puts response.body
    end

    true
  end

end

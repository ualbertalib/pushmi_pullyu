require 'net/http'

class PushmiPullyu::AIP::FedoraFetcher

  RDF_FORMAT = 'text/rdf+n3'.freeze

  def initialize(noid)
    @noid = noid
  end

  def base_path
    PushmiPullyu.options[:fedora][:base_path]
  end

  def object_url(url_extra = nil)
    url = "#{PushmiPullyu.options[:fedora][:url]}#{base_path}/#{pairtree}"
    url += url_extra if url_extra
    url
  end

  def pairtree
    "#{@noid[0..1]}/#{@noid[2..3]}/#{@noid[4..5]}/#{@noid[6..7]}/#{@noid}"
  end

  def download_object(download_path: nil, url_extra: nil,
                      optional: false, rdf: false)
    # Return true on success, raise an error otherwise
    # (or use 'optional' to return false on 404)

    url = object_url(url_extra)
    uri = URI(url)

    request = Net::HTTP::Get.new(uri)
    request.basic_auth(PushmiPullyu.options[:fedora][:user],
                       PushmiPullyu.options[:fedora][:password])

    request['Accept'] = RDF_FORMAT if rdf

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      if download_path
        file = File.open(download_path, 'wb')
        file.write(response.body)
        file.close
      else
        PushmiPullyu.logger.debug(response.body)
      end
      return true
    end

    if response.is_a?(Net::HTTPNotFound)
      raise PushmiPullyu::AIP::FedoraFetchError unless optional
      return false
    end

    raise PushmiPullyu::AIP::FedoraFetchError
  end

end

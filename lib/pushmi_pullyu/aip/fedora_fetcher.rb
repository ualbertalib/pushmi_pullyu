require 'net/http'

class PushmiPullyu::AIP::FedoraFetcher

  class FedoraFetchError < StandardError; end

  RDF_FORMAT = 'text/rdf+n3'.freeze

  def initialize(noid)
    @noid = noid
  end

  def object_url(url_extra = nil)
    url = "#{PushmiPullyu.options[:fedora][:url]}#{base_path}/#{pairtree}"
    url += url_extra if url_extra
    url
  end

  # Return true on success, raise an error otherwise
  # (or use 'optional' to return false on 404)
  def download_object(download_path, url_extra: nil,
                      optional: false, is_rdf: false,
                      should_add_user_email: false)

    uri = URI(object_url(url_extra))

    request = Net::HTTP::Get.new(uri)
    request.basic_auth(PushmiPullyu.options[:fedora][:user],
                       PushmiPullyu.options[:fedora][:password])

    request['Accept'] = RDF_FORMAT if is_rdf

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      body = if should_add_user_email
               PushmiPullyu::AIP::OwnerEmailEditor.new(response.body).run
             else
               response.body
             end
      file = File.open(download_path, 'wb')
      file.write(body)
      file.close
      true
    elsif response.is_a?(Net::HTTPNotFound)
      raise FedoraFetchError unless optional

      false
    else
      raise FedoraFetchError
    end
  end

  private

  def pairtree
    "#{@noid[0..1]}/#{@noid[2..3]}/#{@noid[4..5]}/#{@noid[6..7]}/#{@noid}"
  end

  def base_path
    PushmiPullyu.options[:fedora][:base_path]
  end

end

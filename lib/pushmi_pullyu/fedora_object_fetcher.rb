require 'net/http'
require 'fileutils'

class PushmiPullyu::FedoraObjectFetcher

  attr_accessor :config, :noid

  RDF_FORMAT = 'text/rdf+n3'.freeze

  def initialize(config, noid)
    self.config = config
    self.noid = noid
  end

  def object_url
    "#{config[:fedora][:url]}#{config[:fedora][:base_path]}/#{pairtree}"
  end

  def pairtree
    "#{noid[0..1]}/#{noid[2..3]}/#{noid[4..5]}/#{noid[6..7]}/#{noid}"
  end

  def download_object(options = {})
    url = object_url
    url += options[:url_extra] if options[:url_extra]
    uri = URI(url)

    req = Net::HTTP::Get.new(uri)
    req.basic_auth(config[:fedora][:user], config[:fedora][:password])
    req['Accept'] = options[:accept] if options.key?(:accept)

    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    if options[:download_path]
      file = File.open(options[:download_path], 'wb')
      file.write(res.body)
      file.close
    else
      puts res.body
    end
  end

  def download_rdf_object(options = {})
    download_object(options.merge(accept: RDF_FORMAT))
  end

end

require 'rdf'
require 'rdf/n3'
require 'rest-client'

class PushmiPullyu::AIP::FileListCreator

  IANA = 'http://www.iana.org/assignments/relation/'.freeze
  PREDICATES = {
    proxy_for: RDF::URI('http://www.openarchives.org/ore/terms/proxyFor'),
    first: RDF::URI(IANA + 'first'),
    last: RDF::URI(IANA + 'last'),
    prev: RDF::URI(IANA + 'prev'),
    next: RDF::URI(IANA + 'next'),
    has_part: RDF::URI('http://purl.org/dc/terms/hasPart')
  }.freeze

  class NoProxyURIFound < StandardError; end
  class NoFirstProxyFound < StandardError; end
  class FirstProxyHasPrev < StandardError; end
  class ListSourceFileSetMismatch < StandardError; end

  def initialize(list_source_uri, output_xml_file, file_set_uuids)
    @uri = RDF::URI(list_source_uri)
    @auth_uri = RDF::URI(list_source_uri)
    @auth_uri.user = PushmiPullyu.options[:fedora][:user]
    @auth_uri.password = PushmiPullyu.options[:fedora][:password]
    @output_file = output_xml_file

    # These are the known fileset uuids, used for validation
    @file_set_uuids = file_set_uuids
  end

  def run
    extract_list_source_uuids
    raise ListSourceFileSetMismatch, @uri.to_s if @list_source_uuids.sort != @file_set_uuids.sort

    write_output_file
  end

  def extract_list_source_uuids
    # Note: raises IOError if can't find
    #       raises RDF::ReaderError if can't parse
    @graph = RDF::Graph.load(@auth_uri, validate: true)
    @list_source_uuids = []

    # Fetch first FileSet in list source
    this_proxy = find_first_proxy

    while @list_source_uuids.count <= num_proxies
      @list_source_uuids << uuid_from_proxy(this_proxy)
      next_proxy = find_next_proxy(this_proxy)

      break if next_proxy.nil?

      raise NextPreviousProxyMismatch if this_proxy != find_prev_proxy(next_proxy)

      this_proxy = next_proxy
    end

    raise ProxyCountIncorrect if @list_source_uuids.count != num_proxies
    raise LastProxyFailsValidation if this_proxy != find_last_proxy
  end

  def num_proxies
    @num_proxies ||= @graph.query(subject: @uri, predicate: PREDICATES[:has_part]).count
  end

  def uuid_from_proxy(proxy_uri)
    @graph.query(subject: proxy_uri, predicate: PREDICATES[:proxy_for]) do |statement|
      return statement.object.to_s.split('/').last
    end
    raise NoProxyURIFound, proxy_uri.to_s
  end

  def find_first_proxy
    @graph.query(subject: @uri, predicate: PREDICATES[:first]) do |statement|
      first_uri = statement.object
      # Validate that the first proxy doesn't have a previous one
      raise FirstProxyHasPrev, @uri.to_s if find_prev_proxy(first_uri)

      return first_uri
    end
    raise NoFirstProxyFound, @uri.to_s
  end

  def find_last_proxy
    @graph.query(subject: @uri, predicate: PREDICATES[:last]) do |statement|
      last_uri = statement.object
      # Validate that the last proxy doesn't have a next one
      raise LastProxyHasNext, @uri.to_s if find_next_proxy(last_uri)

      return last_uri
    end
    raise LastProxyFound, @uri.to_s
  end

  def find_next_proxy(proxy_uri)
    @graph.query(subject: proxy_uri, predicate: PREDICATES[:next]) do |statement|
      return statement.object
    end
    nil
  end

  def find_prev_proxy(proxy_uri)
    @graph.query(subject: proxy_uri, predicate: PREDICATES[:prev]) do |statement|
      return statement.object
    end
    nil
  end

  def write_output_file
    File.open(@output_file, 'w') do |file|
      file.write("<file_order>\n")
      @list_source_uuids.each do |uuid|
        file.write("  <uuid>#{uuid}</uuid>\n")
      end
      file.write("</file_order>\n")
    end
  end

end

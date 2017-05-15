require 'pushmi_pullyu/aip'
require 'pushmi_pullyu/aip/solr_fetcher'
require 'pushmi_pullyu/aip/fedora_fetcher'

# Download all of the metadata/datastreams and associated data
# related to an object

class PushmiPullyu::Aip::Downloader

  def self.run(noid)
    new(noid).run
  end

  def initialize(noid)
    @noid = noid
    @fedora_fetcher = PushmiPullyu::Aip::FedoraFetcher.new(noid)
  end

  def run
    make_directories
    PushmiPullyu.logger.info("#{noid}: Retreiving data from Fedora ...")

    [:main_object, :fixity, :content_datastream_metadata, :versions, :thumbnail,
     :characterization, :fedora3foxml, :fedora3foxml_metadata].each do |item|
      path_spec = aip_paths.send(item)
      download_and_log(path_spec)
    end

    # Need content filename from metadata
    download_and_log(aip_paths.content, local_path: content_filename)

    download_permissions
  end

  private

  def download_and_log(path_spec, local_path: nil, fedora_fetcher: nil)
    # Fetcher is either for current object, or for a permission object
    fedora_fetcher ||= @fedora_fetcher

    log_fetching(path_spec)

    local_path ||= full_local_path(path_spec.local)
    rdf = (filename =~ /\.n3$/)

    success = fedora_fetcher.download_object(download_path: local_path,
                                             url_extra: path_spec.remote,
                                             optional: path_spec.optional,
                                             rdf: rdf)
    log_saved(path_spec, success)
  end

  def download_permissions
    aip_logger.info("#{noid}: looking up permissions from Solr ...")
    solr = PushmiPullyu::Aip::SolrFetcher.new(config)
    results = solr.fetch_query_array("accessTo_ssim:#{noid}", fields: 'id')
    if results.empty?
      aip_logger.info("#{noid}: permissions not found")
      return
    end
    results.each do |result|
      permission_id = result['id']
      aip_logger.info("#{noid}: permission object #{permission_id} found")
      download_permission(permission_id)
    end
  end

  def download_permission(permission_id)
    permission_fetcher =
      PushmiPullyu::FedoraObjectFetcher.new(permission_id, config)

    filename = permission_filename(permission_id)

    path_spec = OpenStruct.new(
      remote: nil,
      local: filename,
      optional: false
    )
    download_and_log(path_spec, fetcher: permission_fetcher)
  end

  ### Logging

  def log_fetching(path_spec)
    message = "#{noid}: #{path_spec.local} -- fetching ..."
    PushmiPullyu.logger.info(message)
  end

  def log_saved(path_spec, success: true)
    message = if success
                "#{noid}: #{path_spec.local} -- saved"
              else
                "#{noid}: #{path_spec.local} -- not_found"
              end
    PushmiPullyu.logger.info(message)
  end

  ### Directories

  def aip_directories
    @aip_directories ||= OpenStruct.new(
      objects: "#{data_directory}/objects",
      metadata: "#{data_directory}/objects/metadata",
      logs: "#{data_directory}/logs",
      thumbnails: "#{data_directory}/thumbnails"
    )
  end

  def make_directories
    clean_directories
    PushmiPullyu.logger.debug("#{noid}: Creating directories ...")
    aip_directories.values.each do |path|
      FileUtils.mkdir_p(path)
    end
    PushmiPullyu.logger.debug("#{noid}: Creating directories done")
  end

  def clean_directories
    return unless File.exist?(base_path)
    PushmiPullyu.logger.debug("#{noid}: Nuking directories ...")
    FileUtils.rm_rf(base_path)
  end

  def base_path
    File.expand_path("#{PushmiPullyu.options[:workdir]}/#{noid}")
  end

  def data_path
    "#{base_path}/data"
  end

  def full_local_path(filename)
    "#{data_path}/#{filename}"
  end

  ### Files

  def aip_paths
    @aip_paths ||= OpenStruct.new(
      main_object: OpenStruct.new(
        remote: nil, # Base path
        local: 'objects/metadata/object_metadata.n3',
        optional: false
      ),
      fixity: OpenStruct.new(
        remote: '/content/fcr:fixity',
        local: 'logs/content_fixity_report.n3',
        optional: false
      ),
      content_datastream_metadata: OpenStruct.new(
        remote: '/content/fcr:metadata',
        local: 'objects/metadata/content_fcr_metadata.n3',
        optional: false
      ),
      versions: OpenStruct.new(
        remote: '/content/fcr:versions',
        local: 'objects/metadata/content_versions.n3',
        optional: false
      ),
      content: OpenStruct.new(
        remote: '/content',
        local: nil, # Filename derived from metadata
        optional: false
      ),

      # Optional downloads
      thumbnail: OpenStruct.new(
        remote: '/thumbnail',
        local: 'thumbnails/thumbnail',
        optional: true
      ),
      characterization: OpenStruct.new(
        remote: '/characterization',
        local: '',
        optional: true
      ),
      fedora3foxml: OpenStruct.new(
        remote: '/fedora3foxml',
        local: '',
        optional: true
      ),
      fedora3foxml_metadata: OpenStruct.new(
        remote: '/fedora3foxml/fcr:metadata',
        local: '',
        optional: true
      )
    ).freeze
  end

  def content_filename
    return @content_filename unless @content_filename.nil?

    # Extract filename from main object metadata
    graph = RDF::Graph.load(full_local_path(aip_paths.main_object.local))
    graph.each_statement do |statement|
      if statement.predicate == FILENAME_PREDICATE
        @content_filename = full_local_path("objects/#{statement.object}")
        break
      end
    end
    raise PushmiPullyu::Aip::NoContentFilename unless @content_filename
    @content_filename
  end

  def permission_filename(permission_id)
    full_local_path("objects/metadata/permission_#{permission_id}.n3")
  end

end

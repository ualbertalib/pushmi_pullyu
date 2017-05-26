require 'fileutils'
require 'ostruct'
require 'rdf/n3'

# Download all of the metadata/datastreams and associated data
# related to an object
class PushmiPullyu::AIP::Downloader

  class NoContentFilename < StandardError; end

  FILENAME_PREDICATE = 'info:fedora/fedora-system:def/model#downloadFilename'.freeze

  def initialize(noid)
    @noid = noid
    @fedora_fetcher = PushmiPullyu::AIP::FedoraFetcher.new(@noid)
    PushmiPullyu::AIP.validate(noid)
  end

  def run
    make_directories
    PushmiPullyu.logger.info("#{@noid}: Retreiving data from Fedora ...")

    [:main_object, :fixity, :content_datastream_metadata, :versions, :thumbnail,
     :characterization, :fedora3foxml, :fedora3foxml_metadata].each do |item|
      path_spec = aip_paths[item]
      download_and_log(path_spec)
    end

    # Need content filename from metadata
    download_and_log(aip_paths.content, local_path: content_filename)

    download_permissions

    # Return directory name
    PushmiPullyu::AIP.aip_directory(@noid)
  end

  private

  def download_and_log(path_spec, local_path: nil, fedora_fetcher: nil)
    # Fetcher is either for current object, or for a permission object
    fedora_fetcher ||= @fedora_fetcher

    # Sometimes we don't know filename in advance, so we use local_path ...
    output_file = full_local_path(local_path || path_spec.local)
    url = fedora_fetcher.object_url(path_spec.remote)

    log_fetching(path_spec, url, local_path: output_file)

    rdf = (output_file =~ /\.n3$/)

    success = fedora_fetcher.download_object(download_path: output_file,
                                             url_extra: path_spec.remote,
                                             optional: path_spec.optional,
                                             rdf: rdf)
    log_saved(path_spec, success, local_path: output_file)
  end

  def download_permissions
    PushmiPullyu.logger.info("#{@noid}: looking up permissions from Solr ...")
    results = PushmiPullyu::AIP::SolrFetcher.new(@noid).fetch_permission_object_ids
    if results.empty?
      PushmiPullyu.logger.info("#{@noid}: permissions not found")
    else
      results.each do |permission_id|
        PushmiPullyu.logger.info("#{@noid}: permission object #{permission_id} found")
        download_permission(permission_id)
      end
    end
  end

  def download_permission(permission_id)
    permission_fetcher =
      PushmiPullyu::AIP::FedoraFetcher.new(permission_id)

    filename = permission_filename(permission_id)

    path_spec = OpenStruct.new(
      remote: nil,
      local: filename,
      optional: false
    )
    download_and_log(path_spec, fedora_fetcher: permission_fetcher)
  end

  ### Logging

  def log_fetching(path_spec, url, local_path: nil)
    local_path ||= path_spec.local
    message = "#{@noid}: #{local_path} -- fetching from #{url} ..."
    PushmiPullyu::Logging.log_aip_activity(@noid, message)
  end

  def log_saved(path_spec, success = true, local_path: nil)
    local_path ||= path_spec.local
    message = if success
                "#{@noid}: #{local_path} -- saved"
              else
                "#{@noid}: #{local_path} -- not_found"
              end
    PushmiPullyu::Logging.log_aip_activity(@noid, message)
  end

  ### Directories

  def aip_dirs
    @aip_dirs ||= OpenStruct.new(
      objects: 'objects',
      metadata: 'objects/metadata',
      logs: 'logs',
      thumbnails: 'thumbnails'
    )
  end

  def make_directories
    clean_directories
    PushmiPullyu.logger.debug("#{@noid}: Creating directories ...")
    aip_dirs.to_h.values.each do |path|
      FileUtils.mkdir_p(full_local_path(path))
    end
    PushmiPullyu.logger.debug("#{@noid}: Creating directories done")
  end

  def clean_directories
    return unless File.exist?(base_path)
    PushmiPullyu.logger.debug("#{@noid}: Nuking directories ...")
    FileUtils.rm_rf(base_path)
  end

  def base_path
    PushmiPullyu::AIP.aip_directory(@noid)
  end

  def data_path
    "#{base_path}/data"
  end

  def full_local_path(path)
    "#{data_path}/#{path}"
  end

  ### Files

  def aip_paths
    @aip_paths ||= OpenStruct.new(
      main_object: OpenStruct.new(
        remote: nil, # Base path
        local: "#{aip_dirs.metadata}/object_metadata.n3",
        optional: false
      ),
      fixity: OpenStruct.new(
        remote: '/content/fcr:fixity',
        local: "#{aip_dirs.logs}/content_fixity_report.n3",
        optional: false
      ),
      content_datastream_metadata: OpenStruct.new(
        remote: '/content/fcr:metadata',
        local: "#{aip_dirs.metadata}/content_fcr_metadata.n3",
        optional: false
      ),
      versions: OpenStruct.new(
        remote: '/content/fcr:versions',
        local: "#{aip_dirs.metadata}/content_versions.n3",
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
        local: "#{aip_dirs.thumbnails}/thumbnail",
        optional: true
      ),
      characterization: OpenStruct.new(
        remote: '/characterization',
        local: "#{aip_dirs.logs}/content_characterization.n3",
        optional: true
      ),
      fedora3foxml: OpenStruct.new(
        remote: '/fedora3foxml',
        local: "#{aip_dirs.metadata}/fedora3foxml.xml",
        optional: true
      ),
      fedora3foxml_metadata: OpenStruct.new(
        remote: '/fedora3foxml/fcr:metadata',
        local: "#{aip_dirs.metadata}/fedora3foxml.n3",
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
        @content_filename = "#{aip_dirs.objects}/#{statement.object}"
        break
      end
    end
    raise NoContentFilename unless @content_filename
    @content_filename
  end

  def permission_filename(permission_id)
    "#{aip_dirs.metadata}/permission_#{permission_id}.n3"
  end

end

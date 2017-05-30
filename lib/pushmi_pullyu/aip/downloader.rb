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
  end

  def run
    make_directories
    PushmiPullyu.logger.info("#{@noid}: Retreiving data from Fedora ...")

    [:main_object, :fixity, :content_datastream_metadata, :versions, :thumbnail,
     :characterization, :fedora3foxml, :fedora3foxml_metadata].each do |item|
      path_spec = aip_paths[item]
      download_and_log(path_spec, PushmiPullyu::AIP::FedoraFetcher.new(@noid))
    end

    # Need content filename from metadata
    download_and_log(aip_paths.content, PushmiPullyu::AIP::FedoraFetcher.new(@noid), local_path: content_filename)

    download_permissions

    # Return directory name
    PushmiPullyu::AIP.aip_directory(@noid)
  end

  private

  def download_and_log(path_spec, fedora_fetcher, local_path: nil)
    # Sometimes we don't know filename in advance, so we use local_path ...
    output_file = full_local_path(local_path || path_spec.local)

    log_fetching(fedora_fetcher.object_url(path_spec.remote), output_file)

    is_rdf = (output_file !~ /\.n3$/)

    is_success = fedora_fetcher.download_object(download_path: output_file,
                                                url_extra: path_spec.remote,
                                                optional: path_spec.optional,
                                                is_rdf: is_rdf)
    log_saved(is_success, output_file)
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
    path_spec = OpenStruct.new(
      remote: nil,
      local: permission_filename(permission_id),
      optional: false
    )
    download_and_log(path_spec, PushmiPullyu::AIP::FedoraFetcher.new(permission_id))
  end

  ### Logging

  def log_fetching(url, output_file)
    message = "#{@noid}: #{output_file} -- fetching from #{url} ..."
    PushmiPullyu::Logging.log_aip_activity(aip_directory, message)
  end

  def log_saved(is_success, output_file)
    message = if is_success
                "#{@noid}: #{output_file} -- saved"
              else
                "#{@noid}: #{output_file} -- not_found"
              end
    PushmiPullyu::Logging.log_aip_activity(aip_directory, message)
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
    return unless File.exist?(aip_directory)
    PushmiPullyu.logger.debug("#{@noid}: Nuking directories ...")
    FileUtils.rm_rf(aip_directory)
  end

  def aip_directory
    PushmiPullyu::AIP.aip_directory(@noid)
  end

  def full_local_path(path)
    "#{aip_directory}/data/#{path}"
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
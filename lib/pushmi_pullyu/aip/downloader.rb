require 'fileutils'
require 'ostruct'
require 'rdf/n3'

# Download all of the metadata/datastreams and associated data
# related to an object
class PushmiPullyu::AIP::Downloader

  class NoContentFilename < StandardError; end

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
    path_spec = OpenStruct.new(
      remote: '/content',
      local: content_filename, # Filename derived from metadata
      optional: false
    )
    download_and_log(path_spec, PushmiPullyu::AIP::FedoraFetcher.new(@noid))

    download_permissions
  end

  private

  def download_and_log(path_spec, fedora_fetcher)
    output_file = path_spec.local

    log_fetching(fedora_fetcher.object_url(path_spec.remote), output_file)

    is_rdf = (output_file !~ /\.n3$/)

    is_success = fedora_fetcher.download_object(output_file,
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
      local: "#{aip_dirs.metadata}/permission_#{permission_id}.n3",
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
      objects: "#{aip_directory}/data/objects",
      metadata: "#{aip_directory}/data/objects/metadata",
      logs: "#{aip_directory}/data/logs",
      thumbnails: "#{aip_directory}/data/thumbnails"
    )
  end

  def make_directories
    clean_directories
    PushmiPullyu.logger.debug("#{@noid}: Creating directories ...")
    aip_dirs.to_h.values.each do |path|
      FileUtils.mkdir_p(path)
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
    filename_predicate = RDF::URI('info:fedora/fedora-system:def/model#downloadFilename')

    # Extract filename from main object metadata
    graph = RDF::Graph.load(aip_paths.main_object.local)

    graph.query(predicate: filename_predicate) do |results|
      return "#{aip_dirs.objects}/#{results.object}"
    end

    raise NoContentFilename
  end

end

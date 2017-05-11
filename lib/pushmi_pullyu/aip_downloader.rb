require 'rdf'
require 'rdf/n3'
require 'fileutils'
require 'pushmi_pullyu/aip_logger'
require 'pushmi_pullyu/fedora_object_fetcher'
require 'pushmi_pullyu/solr_fetcher'

# Download all of the metadata/datastreams and associated data
# related to an object

class PushmiPullyu::AipDownloader

  attr_reader :noid, :config, :logger, :aip_logger, :fetcher,
              :workdir, :basedir, :datadir, :objectsdir, :metadatadir, :logsdir,
              :thumbnailsdir,
              :tar_filename, :main_object_filename, :fixity_report_filename,
              :content_datastream_metadata_filename,
              :characterization_filename, :versions_filename,
              :thumbnail_filename, :fedora3foxml_filename,
              :fedora3foxml_metadata_filename,
              :aipcreation_log

  attr_accessor :got_characterization, :got_thumbnail,
                :got_fedora3foxml, :got_fedora3foxml_metadata

  FILENAME_PREDICATE = 'info:fedora/fedora-system:def/model#downloadFilename'.freeze

  FIXITY_PATH = '/content/fcr:fixity'.freeze
  CONTENT_DATASTREAM_METADATA_PATH = '/content/fcr:metadata'.freeze
  CHARACTERIZATION_PATH = '/characterization'.freeze
  VERSIONS_PATH = '/content/fcr:versions'.freeze
  CONTENT_PATH = '/content'.freeze
  THUMBNAIL_PATH = '/thumbnail'.freeze
  FEDORA3FOXML_PATH = '/fedora3foxml'.freeze
  FEDORA3FOXML_METADATA_PATH = '/fedora3foxml/fcr:metadata'.freeze

  def initialize(noid, config = nil, application_logger = nil)
    @noid = noid

    @config = config || PushmiPullyu.options
    @logger = application_logger || PushmiPullyu.logger
    @fetcher = PushmiPullyu::FedoraObjectFetcher.new(self.noid, self.config)

    initialize_directory_names
    initialize_filenames

    # We need to log to application log and to the AIP log
    @aip_logger = PushmiPullyu::AipLogger.new(@noid, aipcreation_log, @logger)

    # We can still archive if some things aren't found, in particular ...
    self.got_characterization = false
    self.got_thumbnail = false
    self.got_fedora3foxml = false
    self.got_fedora3foxml_metadata = false
  end

  def download_objects_and_metadata
    make_object_directories

    aip_logger.info("#{noid}: Retreiving data from Fedora ...")
    download_main_object
    download_fixity_report
    download_content_datastream_metadata
    download_characterization
    download_versions
    download_fedora3foxml
    download_fedora3foxml_metadata

    download_content_datastream
    download_thumbnail_datastream

    download_permissions
  end

  def clean_directories
    return unless File.exist?(basedir)
    logger.debug("#{noid}: Nuking directories ...")
    FileUtils.rm_rf(basedir)
  end

  def initialize_directory_names
    @workdir = File.expand_path(config[:workdir])
    @basedir = "#{workdir}/#{noid}"
    @datadir = "#{basedir}/data"
    @objectsdir = "#{datadir}/objects"
    @metadatadir = "#{datadir}/objects/metadata"
    @logsdir = "#{datadir}/logs"
    @thumbnailsdir = "#{datadir}/thumbnails"
  end

  def initialize_filenames
    @main_object_filename = "#{metadatadir}/object_metadata.n3"
    @fixity_report_filename = "#{logsdir}/content_fixity_report.n3"
    @content_datastream_metadata_filename =
      "#{metadatadir}/content_fcr_metadata.n3"
    @characterization_filename = "#{logsdir}/content_characterization.xml"
    @versions_filename = "#{metadatadir}/content_versions.n3"
    @thumbnail_filename = "#{thumbnailsdir}/thumbnail"
    @fedora3foxml_filename = "#{metadatadir}/fedora3foxml.xml"
    @fedora3foxml_metadata_filename = "#{metadatadir}/fedora3foxml.n3"
    @aipcreation_log = "#{logsdir}/aipcreation.txt"
  end

  def make_object_directories
    clean_directories
    logger.debug("#{noid}: Creating directories ...")
    FileUtils.mkdir_p(basedir)
    FileUtils.mkdir_p(datadir)
    FileUtils.mkdir_p(objectsdir)
    FileUtils.mkdir_p(metadatadir)
    FileUtils.mkdir_p(logsdir)
    FileUtils.mkdir_p(thumbnailsdir)
    logger.debug("#{noid}: Creating directories done")
  end

  def fetch_and_log(path, url_extra: nil, fetcher: nil, rdf: false)
    fetcher ||= @fetcher
    aip_logger.log_fetching(path)
    fetcher.download_object(download_path: path,
                            url_extra: url_extra,
                            rdf: rdf)
    aip_logger.log_saved(path)
  end

  def fetch_and_log_optional(path, url_extra: nil, fetcher: nil, rdf: false)
    fetcher ||= @fetcher
    aip_logger.log_fetching(path)
    success = fetcher.download_object(download_path: path,
                                      url_extra: url_extra,
                                      return_false_on_404: true,
                                      rdf: rdf)
    aip_logger.log_save_status(path, success)
    success
  end

  def download_main_object
    fetch_and_log(main_object_filename, rdf: true)
  end

  def download_fixity_report
    fetch_and_log(fixity_report_filename, url_extra: FIXITY_PATH, rdf: true)
  end

  def download_content_datastream_metadata
    fetch_and_log(content_datastream_metadata_filename,
                  url_extra: CONTENT_DATASTREAM_METADATA_PATH, rdf: true)
  end

  def download_characterization
    success = fetch_and_log_optional(characterization_filename,
                                     url_extra: CHARACTERIZATION_PATH)
    self.got_characterization = success
  end

  def download_versions
    fetch_and_log(versions_filename, url_extra: VERSIONS_PATH, rdf: true)
  end

  def content_filename
    return @content_filename unless @content_filename.nil?
    # Extract filename from main object metadata
    graph = RDF::Graph.load(main_object_filename)
    graph.each_statement do |statement|
      if statement.predicate == FILENAME_PREDICATE
        @content_filename = "#{objectsdir}/#{statement.object}"
        break
      end
    end
    raise PushmiPullyu::NoContentFilename unless @content_filename
    @content_filename
  end

  def download_content_datastream
    fetch_and_log(content_filename, url_extra: CONTENT_PATH)
  end

  def download_thumbnail_datastream
    success = fetch_and_log_optional(thumbnail_filename, url_extra: THUMBNAIL_PATH)
    self.got_thumbnail = success
  end

  def download_permissions
    aip_logger.info("#{noid}: looking up permissions from Solr ...")
    solr = PushmiPullyu::SolrFetcher.new(config)
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

  def permission_filename(permission_id)
    "#{metadatadir}/permission_#{permission_id}.n3"
  end

  def download_permission(permission_id)
    permission_fetcher =
      PushmiPullyu::FedoraObjectFetcher.new(permission_id, config)

    filename = permission_filename(permission_id)

    fetch_and_log(filename, fetcher: permission_fetcher, rdf: true)
  end

  def download_fedora3foxml
    success = fetch_and_log_optional(fedora3foxml_filename,
                                     url_extra: FEDORA3FOXML_PATH)
    self.got_fedora3foxml = success
  end

  def download_fedora3foxml_metadata
    success = fetch_and_log_optional(fedora3foxml_metadata_filename,
                                     url_extra: FEDORA3FOXML_METADATA_PATH, rdf: true)
    self.got_fedora3foxml_metadata = success
  end

end

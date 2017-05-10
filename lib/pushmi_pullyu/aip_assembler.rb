require 'linkeddata'
require 'fileutils'
require 'pushmi_pullyu/fedora_object_fetcher'

# Download all of the metadata/datastreams and associated data
# related to an object

# Was not able to get the filename from downloaded RDF
class PushmiPullyu::NoContentFilename < StandardError; end

class PushmiPullyu::AipAssembler

  attr_reader :noid, :config, :logger, :fetcher,
              :basedir, :objectsdir, :metadatadir, :logsdir, :thumbnailsdir,
              :main_object_filename, :fixity_report_filename,
              :content_datastream_metadata_filename,
              :characterization_filename, :versions_filename,
              :thumbnail_filename

  attr_accessor :got_characterization, :got_thumbnail

  FILENAME_PREDICATE = 'info:fedora/fedora-system:def/model#downloadFilename'.freeze

  FIXITY_PATH = '/content/fcr:fixity'.freeze
  CONTENT_DATASTREAM_METADATA_PATH = '/content/fcr:metadata'.freeze
  CHARACTERIZATION_PATH = '/characterization'.freeze
  VERSIONS_PATH = '/content/fcr:versions'.freeze
  CONTENT_PATH = '/content'.freeze
  THUMBNAIL_PATH = '/thumbnail'.freeze

  def initialize(noid, config = nil, logger = nil)
    @noid = noid

    @config = config || PushmiPullyu.options
    @logger = logger || PushmiPullyu.logger
    @fetcher = PushmiPullyu::FedoraObjectFetcher.new(self.noid, self.config)

    # Directories
    @basedir = File.expand_path("#{self.config[:workdir]}/#{noid}")
    @objectsdir = "#{basedir}/objects"
    @metadatadir = "#{basedir}/objects/metadata"
    @logsdir = "#{basedir}/logs"
    @thumbnailsdir = "#{basedir}/thumbnails"

    # Files
    @main_object_filename = "#{metadatadir}/object_metadata.n3"
    @fixity_report_filename = "#{logsdir}/content_fixity_report.n3"
    @content_datastream_metadata_filename =
      "#{metadatadir}/content_fcr_metadata.n3"
    @characterization_filename = "#{logsdir}/content_characterization.xml"
    @versions_filename = "#{metadatadir}/content_versions.n3"
    @thumbnail_filename = "#{thumbnailsdir}/thumbnail"

    # We can still archive if some things aren't found, in particular ...
    self.got_characterization = false
    self.got_thumbnail = false
  end

  def download_object_and_data
    logger.info("#{noid}: Retreiving data from Fedora ...")
    make_object_directories

    download_main_object
    download_fixity_report
    download_content_datastream_metadata
    download_characterization
    download_versions

    # The next ones depend on the previous ones to get filenames, etc.
    download_content_datastream
    download_thumbnail_datastream
    download_permissions
  end

  # Below should all be private

  def make_object_directories
    logger.debug("#{noid}: Creating directories ...")
    FileUtils.mkdir_p(basedir)
    FileUtils.mkdir_p(objectsdir)
    FileUtils.mkdir_p(metadatadir)
    FileUtils.mkdir_p(logsdir)
    FileUtils.mkdir_p(thumbnailsdir)
    logger.debug("#{noid}: Creating directories done")
  end

  def download_main_object
    log_fetching(main_object_filename)
    @fetcher.download_rdf_object(download_path: main_object_filename)
    log_saved(main_object_filename)
  end

  def download_fixity_report
    log_fetching(fixity_report_filename)
    @fetcher.download_rdf_object(url_extra: FIXITY_PATH,
                                 download_path: fixity_report_filename)
    log_saved(fixity_report_filename)
  end

  def download_content_datastream_metadata
    log_fetching(content_datastream_metadata_filename)
    @fetcher.download_rdf_object(url_extra: CONTENT_DATASTREAM_METADATA_PATH,
                                 download_path: content_datastream_metadata_filename)
    log_saved(content_datastream_metadata_filename)
  end

  def download_characterization
    log_fetching(characterization_filename)
    success = @fetcher.download_object(url_extra: CHARACTERIZATION_PATH,
                                       download_path: characterization_filename,
                                       return_false_on_404: true)
    log_save_status(characterization_filename, success)
    self.got_characterization = success
  end

  def download_versions
    log_fetching(versions_filename)
    @fetcher.download_rdf_object(url_extra: VERSIONS_PATH,
                                 download_path: versions_filename)
    log_saved(versions_filename)
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
    log_fetching(content_filename)
    @fetcher.download_object(url_extra: CONTENT_PATH,
                             download_path: content_filename)
    log_saved(content_filename)
  end

  def download_thumbnail_datastream
    log_fetching(thumbnail_filename)
    success = @fetcher.download_object(url_extra: THUMBNAIL_PATH,
                                       download_path: thumbnail_filename,
                                       return_false_on_404: true)
    log_save_status(thumbnail_filename, success)
    self.got_thumbnail = success
  end

  def download_permissions
    logger.info("#{noid}: looking up permissions from Solr ...")
    solr = PushmiPullyu::SolrFetcher.new(config)
    results = solr.fetch_query_array("accessTo_ssim:#{noid}", fields: 'id')
    if results.empty?
      logger.info("#{noid}: permissions not found")
      return
    end
    results.each do |result|
      permission_id = result['id']
      logger.info("#{noid}: permission object #{permission_id} found")
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
    log_fetching(filename)
    permission_fetcher.download_rdf_object(download_path: filename)
    log_saved(filename)
  end

  def log_fetching(filename)
    logger.info("#{noid}: #{filename} -- fetching ...")
  end

  def log_saved(filename)
    logger.info("#{noid}: #{filename} -- saved")
  end

  def log_not_found(filename)
    logger.info("#{noid}: #{filename} -- not_found")
  end

  def log_save_status(filename, success)
    if success
      log_saved(filename)
    else
      log_not_found(filename)
    end
  end

end

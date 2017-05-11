require 'pushmi_pullyu/aip_downloader_files_directories'
require 'pushmi_pullyu/aip_logger'
require 'pushmi_pullyu/fedora_object_fetcher'
require 'pushmi_pullyu/solr_fetcher'

# Download all of the metadata/datastreams and associated data
# related to an object

class PushmiPullyu::AipDownloader

  include PushmiPullyu::AipDownloaderFilesDirectories

  attr_reader :noid, :config, :logger, :aip_logger, :fetcher,
              :aipcreation_log

  attr_accessor :got_characterization, :got_thumbnail,
                :got_fedora3foxml, :got_fedora3foxml_metadata

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

  private

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

end

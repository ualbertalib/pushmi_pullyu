require 'linkeddata'
require 'fileutils'
require 'pushmi_pullyu/fedora_object_fetcher'

# Download all of the metadata/datastreams and associated data
# related to an object

# Was not able to get the filename from downloaded RDF
class PushmiPullyu::NoContentFilename < StandardError; end

class PushmiPullyu::AipAssembler

  attr_reader :config, :noid, :fetcher,
              :basedir, :objectsdir, :metadatadir, :logsdir, :thumbnailsdir,
              :main_object_filename, :fixity_report_filename,
              :content_datastream_metadata_filename,
              :characterization_filename, :versions_filename

  attr_accessor :got_characterization

  FILENAME_PREDICATE = 'info:fedora/fedora-system:def/model#downloadFilename'.freeze

  FIXITY_PATH = '/content/fcr:fixity'.freeze
  CONTENT_DATASTREAM_METADATA_PATH = '/content/fcr:metadata'.freeze
  CHARACTERIZATION_PATH = '/characterization'.freeze
  VERSIONS_PATH = '/content/fcr:versions'.freeze
  CONTENT_PATH = '/content'.freeze
  THUMBNAIL_PATH = '/thumbnail'.freeze

  def initialize(config, noid)
    @config = config
    @noid = noid
    @fetcher = PushmiPullyu::FedoraObjectFetcher.new(config, noid)

    # Directories
    @basedir = File.expand_path("#{config[:workdir]}/#{noid}")
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

    # If characterization isn't found, we can still archive
    self.got_characterization = false
  end

  def download_object_and_data
    make_object_directories

    download_main_object
    download_fixity_report
    download_content_datastream_metadata
    download_characterization
    download_versions

    # The next ones depend on the previous ones to get filenames, etc.
    download_content_datastream
    # download_thumbnail_datastream
    # download_permissions
  end

  # Below should all be private

  def make_object_directories
    FileUtils.mkdir_p(basedir)
    FileUtils.mkdir_p(objectsdir)
    FileUtils.mkdir_p(metadatadir)
    FileUtils.mkdir_p(logsdir)
    FileUtils.mkdir_p(thumbnailsdir)
  end

  def download_main_object
    @fetcher.download_rdf_object(download_path: main_object_filename)
  end

  def download_fixity_report
    @fetcher.download_rdf_object(url_extra: FIXITY_PATH,
                                 download_path: fixity_report_filename)
  end

  def download_content_datastream_metadata
    @fetcher.download_rdf_object(url_extra: CONTENT_DATASTREAM_METADATA_PATH,
                                 download_path: content_datastream_metadata_filename)
  end

  def download_characterization
    success = @fetcher.download_object(url_extra: CHARACTERIZATION_PATH,
                                       download_path: characterization_filename,
                                       return_false_on_404: true)
    self.got_characterization = success
  end

  def download_versions
    @fetcher.download_rdf_object(url_extra: VERSIONS_PATH,
                                 download_path: versions_filename)
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
    @fetcher.download_object(url_extra: CONTENT_PATH,
                             download_path: content_filename)
  end

end

require 'rdf'
require 'rdf/n3'
require 'fileutils'

# Download all of the metadata/datastreams and associated data
# related to an object

module PushmiPullyu::AipDownloaderFilesDirectories
  FIXITY_PATH = '/content/fcr:fixity'.freeze
  CONTENT_DATASTREAM_METADATA_PATH = '/content/fcr:metadata'.freeze
  CHARACTERIZATION_PATH = '/characterization'.freeze
  VERSIONS_PATH = '/content/fcr:versions'.freeze
  CONTENT_PATH = '/content'.freeze
  THUMBNAIL_PATH = '/thumbnail'.freeze
  FEDORA3FOXML_PATH = '/fedora3foxml'.freeze
  FEDORA3FOXML_METADATA_PATH = '/fedora3foxml/fcr:metadata'.freeze

  FILENAME_PREDICATE = 'info:fedora/fedora-system:def/model#downloadFilename'.freeze

  def self.included(_klass)
    attr_reader :workdir, :basedir, :datadir, :objectsdir, :metadatadir,
                :logsdir, :thumbnailsdir,
                :tar_filename, :main_object_filename, :fixity_report_filename,
                :content_datastream_metadata_filename,
                :characterization_filename, :versions_filename,
                :thumbnail_filename, :fedora3foxml_filename,
                :fedora3foxml_metadata_filename
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

  def clean_directories
    return unless File.exist?(basedir)
    logger.debug("#{noid}: Nuking directories ...")
    FileUtils.rm_rf(basedir)
  end

  private

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

  def permission_filename(permission_id)
    "#{metadatadir}/permission_#{permission_id}.n3"
  end
end

require 'fileutils'
require 'ostruct'
require 'rdf'
require 'rdf/n3'

# Download all of the metadata/datastreams and associated data
# related to an object
class PushmiPullyu::AIP::Downloader

  PREDICATE_URIS = {
    filename: 'http://purl.org/dc/terms/title',
    member_files: 'http://pcdm.org/models#hasFile',
    member_file_sets: 'http://pcdm.org/models#hasMember',
    original_file: 'http://pcdm.org/use#OriginalFile',
    type: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'
  }.freeze

  class NoFileSets < StandardError; end
  class NoMemberFiles < StandardError; end
  class NoContentFilename < StandardError; end
  class NoOriginalFile < StandardError; end

  def initialize(noid, aip_directory)
    @noid = noid
    @aip_directory = aip_directory
  end

  def run
    make_directories

    PushmiPullyu.logger.info("#{@noid}: Retreiving data from Fedora ...")

    # Main object metadata
    object_downloader = PushmiPullyu::AIP::FedoraFetcher.new(@noid)
    download_and_log(object_aip_paths[:main_object], object_downloader)

    # Construct the file ordering file
    list_source_uri = object_downloader.object_url + object_aip_paths.list_source.remote
    PushmiPullyu::AIP::FileListCreator.new(list_source_uri,
                                           object_aip_paths.file_ordering.local,
                                           member_file_set_uuids).run

    member_file_set_uuids.each do |file_set_uuid|
      make_file_set_directories(file_set_uuid)

      # FileSet metadata
      file_set_downloader = PushmiPullyu::AIP::FedoraFetcher.new(file_set_uuid)
      path_spec = file_set_aip_paths(file_set_uuid)[:main_object]
      download_and_log(path_spec, file_set_downloader)

      # Find the original file by looping through the files in the file_set
      original_file_remote_base = nil
      member_files(file_set_uuid).each do |file_path|
        path_spec = OpenStruct.new(
          remote: "/files/#{file_path}/fcr:metadata",
          # Note: local file gets clobbered on each download until it finds the right one
          local: "#{file_set_dirs(file_set_uuid).metadata}/original_file_metadata.n3",
          optional: true
        )
        download_and_log(path_spec, file_set_downloader)
        if original_file?(path_spec.local)
          original_file_remote_base = "/files/#{file_path}"
          break
        end
      end

      raise NoOriginalFile unless original_file_remote_base.present?

      [:content, :fixity].each do |item|
        path_spec = file_aip_paths(file_set_uuid, original_file_remote_base)[item]
        download_and_log(path_spec, file_set_downloader)
      end
    end
  end

  private

  def download_and_log(path_spec, fedora_fetcher)
    output_file = path_spec.local

    log_fetching(fedora_fetcher.object_url(path_spec.remote), output_file)

    is_rdf = (output_file =~ /\.n3$/)
    should_add_user_email = path_spec.to_h.fetch(:should_add_user_email, false)

    is_success = fedora_fetcher.download_object(output_file,
                                                url_extra: path_spec.remote,
                                                optional: path_spec.optional,
                                                is_rdf: is_rdf,
                                                should_add_user_email: should_add_user_email)
    log_saved(is_success, output_file)
  end

  ### Logging

  def log_fetching(url, output_file)
    message = "#{@noid}: #{output_file} -- fetching from #{url} ..."
    PushmiPullyu::Logging.log_aip_activity(@aip_directory, message)
  end

  def log_saved(is_success, output_file)
    message = "#{@noid}: #{output_file} -- #{is_success ? 'saved' : 'not_found'}"
    PushmiPullyu::Logging.log_aip_activity(@aip_directory, message)
  end

  ### Directories

  def aip_dirs
    @aip_dirs ||= OpenStruct.new(
      objects: "#{@aip_directory}/data/objects",
      metadata: "#{@aip_directory}/data/objects/metadata",
      files: "#{@aip_directory}/data/objects/files",
      files_metadata: "#{@aip_directory}/data/objects/metadata/files_metadata",
      logs: "#{@aip_directory}/data/logs",
      file_logs: "#{@aip_directory}/data/logs/files_logs"
    )
  end

  def file_set_dirs(file_set_uuid)
    @file_set_dirs ||= {}
    @file_set_dirs[file_set_uuid] ||= OpenStruct.new(
      metadata: "#{aip_dirs.files_metadata}/#{file_set_uuid}",
      files: "#{aip_dirs.files}/#{file_set_uuid}",
      logs: "#{aip_dirs.file_logs}/#{file_set_uuid}"
    )
  end

  def make_directories
    clean_directories
    PushmiPullyu.logger.debug("#{@noid}: Creating directories ...")
    aip_dirs.to_h.each_value do |path|
      FileUtils.mkdir_p(path)
    end
    PushmiPullyu.logger.debug("#{@noid}: Creating directories done")
  end

  def make_file_set_directories(file_set_uuid)
    PushmiPullyu.logger.debug("#{@noid}: Creating file set #{file_set_uuid} directories ...")
    file_set_dirs(file_set_uuid).to_h.each_value do |path|
      FileUtils.mkdir_p(path)
    end
    PushmiPullyu.logger.debug("#{@noid}: Creating file set #{file_set_uuid} directories done")
  end

  def clean_directories
    return unless File.exist?(@aip_directory)
    PushmiPullyu.logger.debug("#{@noid}: Nuking directories ...")
    FileUtils.rm_rf(@aip_directory)
  end

  ### Files

  def object_aip_paths
    @object_aip_paths ||= OpenStruct.new(
      main_object: OpenStruct.new(
        remote: nil, # Base path
        local: "#{aip_dirs.metadata}/object_metadata.n3",
        should_add_user_email: true,
        optional: false
      ),
      list_source: OpenStruct.new(
        # This is downloaded, but not saved
        remote: '/list_source'
      ),
      # This is constructed, not downloaded
      file_ordering: OpenStruct.new(
        local: "#{aip_dirs.files_metadata}/file_order.xml"
      )
    ).freeze
  end

  def file_set_aip_paths(file_set_uuid)
    @file_set_aip_paths ||= {}
    @file_set_aip_paths[file_set_uuid] ||= OpenStruct.new(
      main_object: OpenStruct.new(
        remote: nil, # Base file_set path
        local: "#{file_set_dirs(file_set_uuid).metadata}/file_set_metadata.n3",
        should_add_user_email: true,
        optional: false
      )
    ).freeze
  end

  def file_aip_paths(file_set_uuid, original_file_remote_base)
    @file_aip_paths ||= {}
    @file_aip_paths[file_set_uuid] ||= OpenStruct.new(
      content: OpenStruct.new(
        remote: original_file_remote_base,
        local: file_set_filename(file_set_uuid),
        optional: false
      ),
      fixity: OpenStruct.new(
        remote: "#{original_file_remote_base}/fcr:fixity",
        local: "#{file_set_dirs(file_set_uuid)[:logs]}/content_fixity_report.n3",
        optional: false
      )
    ).freeze
  end

  def member_file_set_uuids
    @member_file_set_uuids ||= []
    return @member_file_set_uuids unless @member_file_set_uuids.empty?

    member_file_set_predicate = RDF::URI(PREDICATE_URIS[:member_file_sets])

    graph = RDF::Graph.load(object_aip_paths.main_object.local)

    graph.query(predicate: member_file_set_predicate) do |results|
      # Get uuid from end of fedora path
      @member_file_set_uuids << results.object.to_s.split('/').last
    end
    return @member_file_set_uuids unless @member_file_set_uuids.empty?

    raise NoFileSets
  end

  def file_set_filename(file_set_uuid)
    filename_predicate = RDF::URI(PREDICATE_URIS[:filename])

    graph = RDF::Graph.load(file_set_aip_paths(file_set_uuid).main_object.local)

    graph.query(predicate: filename_predicate) do |results|
      return "#{file_set_dirs(file_set_uuid).files}/#{results.object}"
    end

    raise NoContentFilename
  end

  def member_files(file_set_uuid)
    member_file_predicate = RDF::URI(PREDICATE_URIS[:member_files])

    graph = RDF::Graph.load(file_set_aip_paths(file_set_uuid).main_object.local)

    member_files = []
    graph.query(predicate: member_file_predicate) do |results|
      # Get uuid from end of fedora path
      member_files << results.object.to_s.split('/').last
    end
    return member_files if member_files.present?

    raise NoMemberFiles
  end

  def original_file?(metadata_filename)
    type_predicate = RDF::URI(PREDICATE_URIS[:type])
    original_file_uri = RDF::URI(PREDICATE_URIS[:original_file])
    graph = RDF::Graph.load(metadata_filename)
    graph.query(predicate: type_predicate) do |results|
      return true if results.object == original_file_uri
    end
    false
  end

end

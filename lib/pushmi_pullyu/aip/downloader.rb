require 'fileutils'
require 'ostruct'
require 'rdf'
require 'rdf/n3'
require 'net/http'

# Download all of the metadata/datastreams and associated data related to an
# object
class PushmiPullyu::AIP::Downloader

  PREDICATE_URIS = {
    filename: 'http://purl.org/dc/terms/title',
    member_files: 'http://pcdm.org/models#hasFile',
    member_file_sets: 'http://pcdm.org/models#hasMember',
    original_file: 'http://pcdm.org/use#OriginalFile',
    type: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'
  }.freeze

  # class NoFileSets < StandardError; end
  # class NoMemberFiles < StandardError; end
  # class NoContentFilename < StandardError; end
  # class NoOriginalFile < StandardError; end
  class JupiterDownloadError < StandardError; end
  class JupiterCopyError < StandardError; end

  def initialize(entity, aip_directory)
    @entity = entity
    @entity_identifier = "[#{entity[:type]} - #{entity[:uuid]}]".freeze
    @aip_directory = aip_directory
  end

  def run
    PushmiPullyu.logger.info("#{@entity_identifier}: Retreiving data from Jupiter ...")
    make_directories

    # Main object metadata
    download_and_log(object_aip_paths[:main_object])
    download_and_log(object_aip_paths[:file_sets])

    # Get file paths for processing
    file_paths = get_file_paths(object_aip_paths[:file_paths][:remote])

    file_paths[:files].each do |file_path|
      file_uuid = file_path[:file_uuid]
      make_file_set_directories(file_uuid)
      copy_and_log(file_uuid, file_path)
      download_and_log(file_aip_paths(file_uuid)[:fixity])
      download_and_log(file_aip_paths(file_uuid)[:original_file])
      download_and_log(file_aip_paths(file_uuid)[:file_set])
    end
  end

  private

  def copy_and_log(file_uuid, file_path)
    remote = file_path[:file_path]
    files_path = file_set_dirs(file_uuid)[:files]
    output_file = "#{files_path}/#{file_path[:file_name]}"
    log_downloading(remote, output_file)
    FileUtils.copy_file(remote, output_file)

    # TODO: check more than the file being there
    is_success = File.exist? output_file
    log_saved(is_success, output_file)

    raise JupiterCopyError unless is_success
  end

  def authenticate_and_request(url)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    # TODO: This basic_auth call is just a placeholder to be replaced when a
    # proper authentication mechanism is setup on jupiter
    # https://github.com/ualbertalib/jupiter/pull/1370#issuecomment-561799351
    request.basic_auth('admin', 'admin@ualberta.ca')

    Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
  end

  def download_and_log(path_spec)
    output_file = path_spec[:local]
    remote = path_spec[:remote]
    log_downloading(remote, output_file)

    response = authenticate_and_request(remote)

    is_success = false
    if response.is_a?(Net::HTTPSuccess)
      file = File.open(output_file, 'wb')
      file.write(response.body)
      file.close
      # Response was a success and the file was saved to output_file
      is_success = File.exist? output_file
    end

    log_saved(is_success, output_file)
    raise JupiterDownloadError unless is_success
  end

  def get_file_paths(url)
    response = authenticate_and_request(url)
    JSON.parse(response.body, symbolize_names: true)
  end

  def object_uri
    aip_api_url = PushmiPullyu.options[:jupiter][:aip_api_url]
    @object_uri ||= "#{aip_api_url}/#{@entity[:type]}/#{@entity[:uuid]}"
  end

  ### Logging

  def log_downloading(url, output_file)
    message = "#{@entity_identifier}: #{output_file} -- Downloading from #{url} ..."
    PushmiPullyu::Logging.log_aip_activity(@aip_directory, message)
  end

  def log_saved(is_success, output_file)
    message = "#{@entity_identifier}: #{output_file} -- #{is_success ? 'Saved' : 'Failed'}"
    PushmiPullyu::Logging.log_aip_activity(@aip_directory, message)
  end

  ### Directories

  def aip_dirs
    @aip_dirs ||= {
      objects: "#{@aip_directory}/data/objects",
      metadata: "#{@aip_directory}/data/objects/metadata",
      files: "#{@aip_directory}/data/objects/files",
      files_metadata: "#{@aip_directory}/data/objects/metadata/files_metadata",
      logs: "#{@aip_directory}/data/logs",
      file_logs: "#{@aip_directory}/data/logs/files_logs"
    }
  end

  def file_set_dirs(file_set_uuid)
    @file_set_dirs ||= {}
    @file_set_dirs[file_set_uuid] ||= {
      metadata: "#{aip_dirs[:files_metadata]}/#{file_set_uuid}",
      files: "#{aip_dirs[:files]}/#{file_set_uuid}",
      logs: "#{aip_dirs[:file_logs]}/#{file_set_uuid}"
    }
  end

  def make_directories
    PushmiPullyu.logger.debug("#{@entity_identifier}: Creating directories ...")
    clean_directories
    aip_dirs.each_value do |path|
      FileUtils.mkdir_p(path)
    end
    PushmiPullyu.logger.debug("#{@entity_identifier}: Creating directories done")
  end

  def make_file_set_directories(file_set_uuid)
    PushmiPullyu.logger.debug("#{@entity_identifier}: Creating file set #{file_set_uuid} directories ...")
    file_set_dirs(file_set_uuid).each_value do |path|
      FileUtils.mkdir_p(path)
    end
    PushmiPullyu.logger.debug("#{@entity_identifier}: Creating file set #{file_set_uuid} directories done")
  end

  def clean_directories
    return unless File.exist?(@aip_directory)

    PushmiPullyu.logger.debug("#{@entity_identifier}: Nuking directories ...")
    FileUtils.rm_rf(@aip_directory)
  end

  ### Files

  def object_aip_paths
    @object_aip_paths ||= {
      main_object: {
        # Base path
        remote: object_uri,
        local: "#{aip_dirs[:metadata]}/object_metadata.n3"
      },
      file_paths: {
        # This is downloaded for processing but not saved
        remote: "#{object_uri}/file_paths"
      },
      file_sets: {
        remote: "#{object_uri}/filesets",
        local: "#{aip_dirs[:files_metadata]}/file_order.xml"
      }
    }.freeze
  end

  def file_aip_paths(file_set_uuid)
    file_set_paths = file_set_dirs(file_set_uuid)
    @file_aip_paths ||= {}
    @file_aip_paths[file_set_uuid] ||= {
      file: {
        remote: '',
        local: ''
      },
      fixity: {
        remote: "#{object_uri}/filesets/#{file_set_uuid}/fixity",
        local: "#{file_set_paths[:logs]}/content_fixity_report.n3"
      },
      file_set: {
        remote: "#{object_uri}/filesets/#{file_set_uuid}",
        local: "#{file_set_paths[:metadata]}/file_set_metadata.n3"
      },
      original_file: {
        remote: "#{object_uri}/filesets/#{file_set_uuid}/original_file",
        local: "#{file_set_paths[:metadata]}/original_file_metadata.n3"
      }
    }.freeze
  end

end

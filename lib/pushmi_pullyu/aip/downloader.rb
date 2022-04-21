require 'fileutils'
require 'ostruct'
require 'rdf'
require 'rdf/n3'
require 'net/http'
require 'uri'
require 'digest'

# Download all of the metadata/datastreams and associated data related to an object
class PushmiPullyu::AIP::Downloader

  PREDICATE_URIS = {
    filename: 'http://purl.org/dc/terms/title',
    member_files: 'http://pcdm.org/models#hasFile',
    member_file_sets: 'http://pcdm.org/models#hasMember',
    type: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'
  }.freeze

  class JupiterDownloadError < StandardError; end
  class JupiterCopyError < StandardError; end
  class JupiterAuthenticationError < StandardError; end

  def initialize(entity, aip_directory)
    @entity = entity
    @entity_identifier = "[#{entity[:type]} - #{entity[:uuid]}]".freeze
    @aip_directory = aip_directory
  end

  def run
    PushmiPullyu.logger.info("#{@entity_identifier}: Retreiving data from Jupiter ...")

    authenticate_http_calls
    make_directories

    # Main object metadata
    download_and_log(object_aip_paths[:main_object_remote],
                     object_aip_paths[:main_object_local])
    download_and_log(object_aip_paths[:file_sets_remote],
                     object_aip_paths[:file_sets_local])

    # Get file paths for processing
    file_paths = get_file_paths(object_aip_paths[:file_paths_remote])

    file_paths[:files].each do |file_path|
      file_uuid = file_path[:file_uuid]
      make_file_set_directories(file_uuid)
      copy_and_log(file_uuid, file_path)
      file_aip_path = file_aip_paths(file_uuid)
      download_and_log(file_aip_path[:fixity_remote],
                       file_aip_path[:fixity_local])
      download_and_log(file_aip_path[:file_set_remote],
                       file_aip_path[:file_set_local])
    end
  end

  private

  def copy_and_log(file_uuid, file_path)
    remote = file_path[:file_path]
    remote_checksum = file_path[:file_checksum]
    files_path = file_set_dirs(file_uuid)[:files]
    output_file = "#{files_path}/#{file_path[:file_name]}"
    log_downloading(remote, output_file)
    FileUtils.copy_file(remote, output_file)

    is_success = File.exist?(output_file) &&
                 File.size(remote) == File.size(output_file) &&
                 compare_md5(output_file, remote_checksum)

    log_saved(is_success, output_file)

    raise JupiterCopyError unless is_success
  end

  def compare_md5(local, remote_checksum)
    local_md5 = Digest::MD5.file local
    local_md5.base64digest == remote_checksum
  end

  def authenticate_http_calls
    @uri = URI.parse(PushmiPullyu.options[:jupiter][:jupiter_url])
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl = true if @uri.instance_of? URI::HTTPS
    request = Net::HTTP::Post.new("#{@uri.request_uri}auth/system")
    request.set_form_data(
      email: PushmiPullyu.options[:jupiter][:user],
      api_key: PushmiPullyu.options[:jupiter][:api_key]
    )
    response = @http.request(request)
    # If we cannot find the set-cookie header then the session was not set
    raise JupiterAuthenticationError if response.response['set-cookie'].nil?

    @cookies = response.response['set-cookie']
  end

  def download_and_log(remote, local)
    log_downloading(remote, local)

    @uri = URI.parse(PushmiPullyu.options[:jupiter][:jupiter_url])
    request = Net::HTTP::Get.new(@uri.request_uri + remote)
    # add previously stored cookies
    request['Cookie'] = @cookies

    response = @http.request(request)
    is_success = if response.is_a?(Net::HTTPSuccess)
                   File.binwrite(local, response.body)
                   # Response was a success and the file was saved to local
                   File.exist? local
                 end

    log_saved(is_success, local)
    raise JupiterDownloadError unless is_success
  end

  def get_file_paths(url)
    request = Net::HTTP::Get.new(@uri.request_uri + url)
    # add previously stored cookies
    request['Cookie'] = @cookies

    response = @http.request(request)

    JSON.parse(response.body, symbolize_names: true)
  end

  def object_uri
    aip_api_url = PushmiPullyu.options[:jupiter][:aip_api_path]
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
      # Base path
      main_object_remote: object_uri,
      main_object_local: "#{aip_dirs[:metadata]}/object_metadata.n3",
      file_sets_remote: "#{object_uri}/filesets",
      file_sets_local: "#{aip_dirs[:files_metadata]}/file_order.xml",
      # This is downloaded for processing but not saved
      file_paths_remote: "#{object_uri}/file_paths"
    }.freeze
  end

  def file_aip_paths(file_set_uuid)
    file_set_paths = file_set_dirs(file_set_uuid)
    @file_aip_paths ||= {}
    @file_aip_paths[file_set_uuid] ||= {
      fixity_remote: "#{object_uri}/filesets/#{file_set_uuid}/fixity",
      fixity_local: "#{file_set_paths[:logs]}/content_fixity_report.n3",
      file_set_remote: "#{object_uri}/filesets/#{file_set_uuid}",
      file_set_local: "#{file_set_paths[:metadata]}/file_set_metadata.n3"
    }.freeze
  end

end

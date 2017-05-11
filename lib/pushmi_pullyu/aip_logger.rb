require 'rdf'
require 'rdf/n3'
require 'fileutils'
require 'pushmi_pullyu/fedora_object_fetcher'
require 'pushmi_pullyu/solr_fetcher'

class PushmiPullyu::AipLogger

  attr_reader :noid, :logger

  def initialize(noid, aip_log_file, application_logger = nil)
    @noid = noid
    @logger = application_logger || PushmiPullyu.logger
    @aipcreation_log = aip_log_file
  end

  def aip_logger
    @aip_logger ||= Logger.new(@aipcreation_log) do |logger|
      logger.level = Logger::INFO
    end
  end

  # We want to log to the main application log, and to the AIP creation log
  def info(msg)
    logger.info(msg)
    aip_logger.info(msg)
  end

  def log_fetching(filename)
    info("#{noid}: #{filename} -- fetching ...")
  end

  def log_saved(filename)
    info("#{noid}: #{filename} -- saved")
  end

  def log_not_found(filename)
    info("#{noid}: #{filename} -- not_found")
  end

  def log_save_status(filename, success)
    if success
      log_saved(filename)
    else
      log_not_found(filename)
    end
  end

end

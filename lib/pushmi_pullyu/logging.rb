require 'logger'

# PushmiPullyu::Logging is a standard Ruby logger wrapper
module PushmiPullyu::Logging
  # Simple formatter which only displays the message.
  # Taken from ActiveSupport
  class SimpleFormatter < Logger::Formatter

    # This method is invoked when a log event occurs
    def call(_severity, _timestamp, _program_name, msg)
      "#{msg.is_a?(String) ? msg : msg.inspect}\n"
    end

  end

  def self.initialize_logger(log_target = STDOUT)
    @logger = Logger.new(log_target)
    @logger.level = Logger::INFO
    @logger
  end

  def self.logger
    @logger ||= initialize_logger
  end

  def self.log_aip_activity(aip_directory, message)
    log_file = "#{aip_directory}/data/logs/aipcreation.log"
    aip_logger = Logger.new(log_file)
    aip_logger.level = logger.level

    # Log to both the application log, and the log file that gets archived in the AIP
    logger.info(message)
    aip_logger.info(message)

    aip_logger.close
  end

  def self.log_preservation_event(deposited_file)
    preservation_logger = Logger.new("#{PushmiPullyu.options[:logdir]}/preservation_events.log")

    message = "#{deposited_file.name} was successfully deposited into Swift Storage! \n"\
    "Here are the details of this preservation event: \n"\
    "\t NOID: '#{deposited_file.name}' \n"\
    "\t Timestamp of Completion: '#{deposited_file.last_modified}' \n"\
    "\t AIP Checksum: '#{deposited_file.etag}' \n"\
    "\t Metadata: #{deposited_file.metadata} \n"

    # Log to both the application log, and the preservation log file
    logger.info(message)
    preservation_logger.info(message)

    preservation_logger.close
  end

  def self.logger=(log)
    @logger = log
  end

  def self.reopen
    if @logger
      @logger.reopen
    else
      @logger = initialize_logger
    end
  end

  def logger
    PushmiPullyu::Logging.logger
  end
end

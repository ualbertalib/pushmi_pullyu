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
    aip_logger = Logger.new(File.expand_path(log_file))
    aip_logger.level = logger.level

    # Log to both the application log, and the log file that gets archived in the AIP
    logger.info(message)
    aip_logger.info(message)

    aip_logger.close
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

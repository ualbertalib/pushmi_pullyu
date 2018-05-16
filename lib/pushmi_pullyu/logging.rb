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

  def logger
    PushmiPullyu::Logging.logger
  end

  class << self

    attr_writer :logger

    def initialize_logger(log_target = STDOUT)
      @logger = Logger.new(log_target)
      @logger.level = Logger::INFO
      @logger
    end

    def logger
      @logger ||= initialize_logger
    end

    def log_aip_activity(aip_directory, message)
      log_file = "#{aip_directory}/data/logs/aipcreation.log"
      aip_logger = Logger.new(log_file)
      aip_logger.level = logger.level

      # Log to both the application log, and the log file that gets archived in the AIP
      logger.info(message)
      aip_logger.info(message)

      aip_logger.close
    end

    def log_preservation_event(deposited_file, aip_directory)
      preservation_logger = Logger.new("#{PushmiPullyu.options[:logdir]}/preservation_events.log")

      message = "#{deposited_file.name} was successfully deposited into Swift Storage!\n"\
      "Here are the details of this preservation event:\n"\
      "\tNOID: '#{deposited_file.name}'\n"\
      "\tTimestamp of Completion: '#{deposited_file.last_modified}'\n"\
      "\tAIP Checksum: '#{deposited_file.etag}'\n"\
      "\tMetadata: #{deposited_file.metadata}\n"\

      file_details = file_log_details(aip_directory)

      if file_details.present?
        message << "\tFile Details:\n"
        file_details.each do |file_detail|
          message << %(\t\t{"fileset_uuid": "#{file_detail[:fileset_name]}",
\t\t"details": {
\t\t\t"file_name": "#{file_detail[:file_name]}",
\t\t\t"file_type": "#{file_detail[:file_extension]}",
\t\t\t"file_size": #{file_detail[:file_size]}
\t\t}}\n)
        end
      end

      # Log to both the application log, and the preservation log file
      logger.info(message)
      preservation_logger.info(message)

      preservation_logger.close
    end

    def reopen
      if @logger
        @logger.reopen
      else
        @logger = initialize_logger
      end
    end

    private

    def file_log_details(aip_directory)
      file_details = []
      data_files_location = "#{aip_directory}/data/objects/files"

      if Dir.exist?(data_files_location)
        Dir.glob("#{data_files_location}/*") do |folder|
          Dir.glob("#{folder}/*") do |file|
            file_details << {
              fileset_name: File.dirname(file).split('/')[-1],
              file_name: File.basename(file),
              file_size: File.size(file),
              file_extension: File.extname(file).strip.downcase[1..-1]
            }
          end
        end
      end

      file_details
    end

  end
end

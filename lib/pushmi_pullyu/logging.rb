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

    def initialize_loggers(log_target: $stdout, events_target: $stdout, json_target: $stdout)
      @preservation_logger = Logger.new(events_target)
      @preservation_json_logger = Logger.new(json_target)

      @logger = Logger.new(log_target)
      @logger.level = Logger::INFO
      @logger
    end

    def logger
      @logger ||= initialize_loggers
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

    def log_preservation_event(message, message_json)
      logger.info(message)
      @preservation_logger.info(message)
      @preservation_json_logger.info("#{message_json},")
    end

    def log_preservation_success(entity, deposited_file, aip_directory)
      message = "#{deposited_file.name} was successfully deposited into Swift Storage!\n" \
                "Here are the details of this preservation event:\n" \
                "\tUUID: '#{deposited_file.name}'\n" \
                "\tTimestamp of Completion: '#{deposited_file.last_modified}'\n" \
                "\tAIP Checksum: '#{deposited_file.etag}'\n" \
                "\tMetadata: #{deposited_file.metadata}\n" \

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

      message_information = {
        event_type: :success,
        event_time: Time.now.to_s,
        entity_type: entity[:type],
        entity_uuid: entity[:uuid],
        event_details: preservation_success_to_json(deposited_file, aip_directory)
      }

      log_preservation_event(message, message_information.to_json)
    end

    def log_preservation_fail_and_retry(entity, try_attempt, exception)
      message = "#{entity[:type]} failed to be deposited and will try again.\n" \
                "Here are the details of this preservation event:\n" \
                "\t#{entity[:type]} uuid: #{entity[:uuid]}" \
                "\tReadding to preservation queue with try attempt: #{try_attempt}\n" \
                "\tError of type: #{exception.class.name}\n" \
                "\tError message: #{exception.message}\n"

      message_information = {
        event_type: :fail_and_retry,
        event_time: Time.now.to_s,
        entity_type: entity[:type],
        entity_uuid: entity[:uuid],
        try_attempt: try_attempt,
        error_message: exception.message
      }

      log_preservation_event(message, message_information.to_json)
    end

    def log_preservation_failure(entity, try_attempt, exception)
      message = "#{entity[:type]} failed to be deposited.\n" \
                "Here are the details of this preservation event:\n" \
                "\t#{entity[:type]} uuid: #{entity[:uuid]}" \
                "\tRetry attempt: #{try_attempt}\n"

      message_information = {
        event_type: :fail_and_retry,
        event_time: Time.now.to_s,
        entity_type: entity[:type],
        entity_uuid: entity[:uuid],
        try_attempt: try_attempt,
        error_message: exception.message
      }

      log_preservation_event(message, message_information.to_json)
    end

    def log_preservation_attempt(entity, try_attempt)
      message = "#{entity[:type]} will attempt to be deposited.\n" \
                "Here are the details of this preservation event:\n" \
                "\t#{entity[:type]} uuid: #{entity[:uuid]}" \
                "\tRetry attempt: #{try_attempt}\n"

      message_information = {
        event_type: :attempt,
        event_time: Time.now.to_s,
        entity_type: entity[:type],
        entity_uuid: entity[:uuid],
        try_attempt: try_attempt
      }

      log_preservation_event(message, message_information.to_json)
    end

    ###
    # Provides an alternative logging method in json format for the convenience of
    # parsing in the process of auditing against OpenStack Swift preservation.
    #
    # output format:
    #  I, [2022-04-06T11:07:21.983875 #20791]  INFO -- : \
    # {
    #  "do_uuid": "83b5d21f-a60a-43ba-945a-f03deec64a1d",
    #  "aip_deposited_at": "Thu, 07 Apr 2022 16:37:00 GMT",
    #  "aip_md5sum": "fe5832a510799b04c1c503e46dc3b589",
    #  "aip_sha256": "",
    #  "aip_metadata": "{\"project-id\":\"83b5d21f-a60a-43ba-945a-f03deec64a1d\",
    #                  \"aip-version\":\"1.0\",
    #                  \"project\":\"ERA\",
    #                  \"promise\":\"bronze\"}",
    #  "aip_file_details": [
    #   {
    #     "fileset_uuid": "b2c6ac0f-f2ed-489e-bbae-bd26465207aa",
    #     "file_name": "Spallacci_Amanda_202103_PhD.pdf",
    #     "file_type": "pdf",
    #     "file_size": "2051363"
    #    }
    #   ]
    # }
    #
    # note:
    #   to parse, the prefix "I, ... INFO --:" in each line needs to be
    #   stripped using a bash command such as "sed"
    def preservation_success_to_json(deposited_file, aip_directory)
      message = {}

      message['do_uuid'] = deposited_file.name.to_s
      message['aip_deposited_at'] = deposited_file.last_modified.to_s
      message['aip_md5sum'] = deposited_file.etag.to_s
      message['aip_sha256'] = ''
      message['aip_metadata'] = deposited_file.metadata

      file_details = file_log_details(aip_directory)

      tmp_details = []
      if file_details.present?
        file_details.each do |file_detail|
          tmp_hash = {}
          tmp_hash['fileset_uuid'] = file_detail[:fileset_name].to_s
          tmp_hash['file_name'] = file_detail[:file_name].to_s
          tmp_hash['file_type'] = file_detail[:file_extension].to_s
          tmp_hash['file_size'] = file_detail[:file_size].to_s
          tmp_details << tmp_hash
        end
      end

      message['aip_file_details'] = tmp_details
      message
    end

    def reopen
      if @logger
        @logger.reopen
      else
        @logger = initialize_loggers
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
              file_extension: File.extname(file).strip.downcase[1..]
            }
          end
        end
      end

      file_details
    end

  end
end

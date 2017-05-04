require 'yaml'
class PushmiPullyu::FedoraConfig

  include PushmiPullyu::Logging

  attr_accessor :config_file, :url, :user, :password, :base_path

  def initialize
    self.config_file = ENV['FEDORA_CONFIG_FILE'] ||
                       File.expand_path(File.dirname(__FILE__) + '../../../config/fedora.yml')

    self.url = ENV['FEDORA_URL']
    self.user = ENV['FEDORA_USER']
    self.password = ENV['FEDORA_PASSWORD']
    self.base_path = ENV['FEDORA_BASEPATH']
  end

  def process_options(opts)
    opts.on('-fc', '--fedora-config-file FILE',
            "Location of Fedora configuration (Default: #{config_file})") do |filename|
      config_file = filename
    end

    opts.separator ''

    load_from_config_file
  end

  def load_from_config_file
    if config_file
      # Should we error if the config_file is not found? Log for now ...
      unless File.exist?(config_file)
        logger.debug "Config file #{config_file} not found"
        return
      end
      yaml_load = YAML.load_file(config_file)
      ['url', 'user', 'password', 'base_path'].each do |attr|
        # If it's not set yet, and if it's in the config file ...
        if send(attr.to_sym).nil? && yaml_load.has_key?(attr)
          send(:"#{attr}=", yaml_load[attr])
        end
      end
    end
  end

end

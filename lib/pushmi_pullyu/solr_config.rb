require 'yaml'
class PushmiPullyu::SolrConfig

  include PushmiPullyu::Logging

  attr_accessor :config_file, :url

  def initialize
    self.config_file = ENV['SOLR_CONFIG_FILE'] ||
                       File.expand_path(File.dirname(__FILE__) + '../../../config/solr.yml')

    self.url = ENV['SOLR_URL']
  end

  def process_options(opts)
    opts.on('-sc', '--solr-config-file FILE',
            "Location of Solr configuration (Default: #{config_file})") do |filename|
      self.config_file = filename
    end

    opts.separator ''

    load_from_config_file
  end

  def load_from_config_file
    return unless config_file
    # Should we error if the config_file is not found? Log for now ...
    unless File.exist?(config_file)
      logger.debug "Config file #{config_file} not found"
      return
    end
    yaml_load = YAML.load_file(config_file)
    ['url'].each do |attr|
      # If it's not set yet, and if it's in the config file ...
      if send(attr.to_sym).nil? && yaml_load.key?(attr)
        send(:"#{attr}=", yaml_load[attr])
      end
    end
  end

end

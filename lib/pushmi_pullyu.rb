require 'pushmi_pullyu/logging'

require 'pushmi_pullyu/aip'
require 'pushmi_pullyu/aip/creator'
require 'pushmi_pullyu/aip/downloader'
require 'pushmi_pullyu/aip/solr_fetcher'
require 'pushmi_pullyu/aip/fedora_fetcher'
require 'pushmi_pullyu/cli'
require 'pushmi_pullyu/preservation_queue'
require 'pushmi_pullyu/swift_depositer'
require 'pushmi_pullyu/version'

require 'active_support'
require 'active_support/core_ext'

# PushmiPullyu main module
module PushmiPullyu

  DEFAULTS = {
    daemonize: false,
    debug: false,
    logfile: 'log/pushmi_pullyu.log',
    minimum_age: 0,
    monitor: false,
    piddir: 'tmp/pids',
    workdir: 'tmp/work',
    process_name: 'pushmi_pullyu',
    queue_name: 'dev:pmpy_queue',
    redis: {
      host: 'localhost',
      port: 6379
    },
    # TODO: rest of these are examples for solr/fedora/swift... feel free to fill them in correctly
    solr: {
      url: 'http://localhost:8983/solr/development'
    },
    fedora: {
      url: 'http://localhost:8983/fedora/rest',
      user: 'fedoraAdmin',
      password: 'fedoraAdmin',
      base_path: '/dev'
    },
    swift: {
      auth_version: 'v1.0',
      tenant: 'tester',
      username: 'test:tester',
      password: 'testing',
      endpoint: 'http://127.0.0.1:8080',
      container: 'ERA'
    }
  }.freeze

  def self.options
    @options ||= DEFAULTS.dup
  end

  def self.options=(opts)
    options.merge!(opts)
  end

  def self.override_options(opts)
    @options = opts
  end

  def self.logger
    PushmiPullyu::Logging.logger
  end

  def self.logger=(log)
    PushmiPullyu::Logging.logger = log
  end

  def self.server_running=(status)
    @server_running = status
  end

  def self.reset_logger=(status)
    @reset_logger = status
  end

  def self.server_running?
    @server_running
  end

  def self.continue_polling?
    server_running? && !reset_logger?
  end

  def self.reset_logger?
    @reset_logger
  end
end

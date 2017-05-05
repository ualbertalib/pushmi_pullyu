# PushmiPullyu::Config stores PushmiPullyu configuration
class PushmiPullyu::Config

  LOGFILE = 'log/pushmi_pullyu.log'.freeze
  PIDDIR  = 'tmp/pids'.freeze
  PROCESS_NAME = 'pushmi_pullyu'.freeze

  # TODO: Add config for redis, swift, fedora, solr, daemon (pids,process info), logging
  # where to override this? consume this from a yaml file? env vars? command line?
  attr_accessor :debug, :daemonize, :logfile, :minimum_age, :monitor, :piddir, :process_name, :queue_name, :redis_host,
                :redis_port, :fedora

  def initialize
    self.daemonize = false
    self.debug = false
    self.logfile = LOGFILE
    self.monitor = false
    self.piddir = PIDDIR
    self.process_name = PROCESS_NAME
    self.redis_host = 'localhost'
    self.redis_port = 6379
    self.queue_name = 'dev:pmpy_queue'
    self.minimum_age = 0
    self.fedora = PushmiPullyu::FedoraConfig.new
  end

end

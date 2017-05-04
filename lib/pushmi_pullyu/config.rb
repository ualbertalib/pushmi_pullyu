# PushmiPullyu::Config stores PushmiPullyu configuration
class PushmiPullyu::Config

  LOGFILE = 'log/pushmi_pullyu.log'.freeze
  PIDDIR  = 'tmp/pids'.freeze
  PROCESS_NAME = 'pushmi_pullyu'.freeze

  # TODO: Add config for redis, swift, fedora, solr, daemon (pids,process info), logging
  # where to override this? consume this from a yaml file? env vars? command line?
  attr_accessor :debug, :daemonize, :logfile, :monitor, :piddir, :process_name, :fedora

  def initialize
    self.daemonize = false
    self.debug = false
    self.logfile = LOGFILE
    self.monitor = false
    self.piddir = PIDDIR
    self.process_name = PROCESS_NAME
    self.fedora = PushmiPullyu::FedoraConfig.new()
  end

end

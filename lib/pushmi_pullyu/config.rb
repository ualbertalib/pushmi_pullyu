# PushmiPullyu::Config stores PushmiPullyu configuration
class PushmiPullyu::Config

  LOGFILE = 'log/pushmi_pullyu.log'.freeze

  # TODO: Add config for redis, swift, fedora, solr, daemon (pids,process info), logging
  # where to override this? consume this from a yaml file? env vars? command line?
  attr_accessor :debug, :daemonize, :logfile

  def initialize
    self.daemonize = false
    self.debug = false
    self.logfile = LOGFILE
  end

end

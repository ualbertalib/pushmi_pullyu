# PushmiPullyu::Config stores PushmiPullyu configuration
class PushmiPullyu::Config

  # TODO: Add config for redis, swift, fedora, solr, daemon (pids,process info), logging
  # where to override this? consume this from a yaml file? env vars? command line?
  attr_accessor :debug, :daemonize

  def initialize
    self.daemonize = false
    self.debug = false
  end

end

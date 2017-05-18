# disable Rollbar reporting even if a Rollbar token is passed
Rollbar.preconfigure do |config|
  config.before_process << proc do |_options|
    raise Rollbar::Ignore
  end
end

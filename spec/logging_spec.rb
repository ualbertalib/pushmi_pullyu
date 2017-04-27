require 'spec_helper'

##
# Dummy class, so that we can mix in the Logging module and test it.
#
class TestLogging

  include PushmiPullyu::Logging

end

describe PushmiPullyu::Logging do
  before :all do
    @object = TestLogging.new
  end

  after(:all) do
    PushmiPullyu::Logging.logger.level = Logger::INFO
  end

  # TODO: Add specs
  # describe 'logging' do

  # end
end

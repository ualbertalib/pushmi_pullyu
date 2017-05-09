require 'bundler/setup'
require 'pushmi_pullyu'
require 'pry'

# Require support scripts
Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.disable_monkey_patching!

  config.profile_examples = 2

  config.order = :random

  Kernel.srand config.seed
end

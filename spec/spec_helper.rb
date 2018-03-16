require 'coveralls'
Coveralls.wear!

require 'bundler/setup'
require 'pushmi_pullyu'
require 'pry'

# Require support scripts
Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    # Will be default in RSpec 4
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Mocks
  config.mock_with :rspec do |mocks|
    # Will be default in RSpec 4
    mocks.verify_partial_doubles = true
  end

  # Will be default in RSpec 4
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Allow filtering by "focus" tag
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  # Be more verbose when running a single test
  config.default_formatter = 'doc' if config.files_to_run.one?

  # Disable monkey-patched syntaxes
  config.disable_monkey_patching!

  # Show the 2 slowest specs
  config.profile_examples = 2

  # Randomize - if there's an order where the tests break, a seed can be passed
  # in via --seed to reproduce
  config.order = :random
  Kernel.srand config.seed

  # Prevent vcr from returning text body as a base64 (e.g., when an umlaut is used)
  VCR.configure do |c|
    c.before_record do |i|
      i.response.body.force_encoding('UTF-8')
    end
    c.preserve_exact_body_bytes do |http_message|
      http_message.body.encoding.name == 'ASCII-8BIT' ||
        !http_message.body.valid_encoding?
    end
  end
end

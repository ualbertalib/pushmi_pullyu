# Suggested docs
# --------------
# https://relishapp.com/vcr/vcr/docs
# http://www.rubydoc.info/gems/vcr/frames
require 'vcr'
require 'webmock/rspec'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/support/http_cache/vcr'
  config.hook_into :webmock

  # Only want VCR to intercept requests to external URLs.
  config.ignore_localhost = true

  # Prevent vcr from returning text body as a base64 (e.g., when an umlaut is used)
  config.before_record do |i|
    i.response.body.force_encoding('UTF-8')
  end
  config.preserve_exact_body_bytes do |http_message|
    http_message.body.encoding.name == 'ASCII-8BIT' ||
      !http_message.body.valid_encoding?
  end
end

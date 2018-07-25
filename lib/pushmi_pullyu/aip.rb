require 'fileutils'

module PushmiPullyu::AIP
  class NoidInvalid < StandardError; end

  def create(noid)
    raise NoidInvalid if noid.blank? || noid.include?('/')

    aip_directory = "#{PushmiPullyu.options[:workdir]}/#{noid}"
    aip_filename = "#{aip_directory}.tar"

    PushmiPullyu::AIP::Downloader.new(noid, aip_directory).run
    PushmiPullyu::AIP::Creator.new(noid, aip_directory, aip_filename).run

    yield aip_filename, aip_directory

    FileUtils.rm_rf(aip_filename) if File.exist?(aip_filename)
    FileUtils.rm_rf(aip_directory) if File.exist?(aip_directory)
  end

  # rubocop:disable Style/AccessModifierDeclarations
  module_function :create
end

require 'fileutils'
require 'uuid'

module PushmiPullyu::AIP
  class EntityInvalid < StandardError; end
  module_function

  def create(entity)
    raise EntityInvalid if entity.nil? ||
                           UUID.validate(entity[:uuid]).nil? ||
                           entity[:type].blank?

    aip_directory = "#{PushmiPullyu.options[:workdir]}/#{entity[:uuid]}"
    aip_filename = "#{aip_directory}.tar"

    PushmiPullyu::AIP::Downloader.new(entity, aip_directory).run
    PushmiPullyu::AIP::Creator.new(entity[:uuid], aip_directory, aip_filename).run

    yield aip_filename, aip_directory

    FileUtils.rm_rf(aip_filename) if File.exist?(aip_filename)
    FileUtils.rm_rf(aip_directory) if File.exist?(aip_directory)
  end
end

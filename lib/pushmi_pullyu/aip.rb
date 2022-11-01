require 'fileutils'
require 'uuid'

module PushmiPullyu::AIP
  class EntityInvalid < StandardError; end
  module_function

  def create(entity)
    raise EntityInvalid if entity.nil? ||
                           UUID.validate(entity[:uuid]) != true ||
                           entity[:type].blank?

    aip_directory = "#{PushmiPullyu.options[:workdir]}/#{entity[:uuid]}"
    aip_filename = "#{aip_directory}.tar"
    begin
      PushmiPullyu::AIP::Downloader.new(entity, aip_directory).run
      PushmiPullyu::AIP::Creator.new(entity[:uuid], aip_directory, aip_filename).run

      yield aip_filename, aip_directory
    # Here we will ensure the files are removed even if an exception comes up.
    # We will leave the exception handling when we actually create an AIP using
    # this method.
    ensure
      # We need to remove the files after creation no matter what
      FileUtils.rm_rf(aip_filename)
      FileUtils.rm_rf(aip_directory)
    end
  end
end

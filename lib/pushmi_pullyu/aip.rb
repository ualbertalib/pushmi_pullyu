require 'fileutils'
require 'uuid'

module PushmiPullyu::AIP
  class EntityInvalid < StandardError; end
  module_function

  def create(entity)
    raise EntityInvalid if entity.blank? ||
                           UUID.validate(entity[:uuid]).blank? ||
                           entity[:type].blank?

    aip_directory = "#{PushmiPullyu.options[:workdir]}/#{entity[:uuid]}"
    aip_filename = "#{aip_directory}.tar"
    begin
      PushmiPullyu::AIP::Downloader.new(entity, aip_directory).run
      PushmiPullyu::AIP::Creator.new(entity[:uuid], aip_directory, aip_filename).run

      yield aip_filename, aip_directory
    # Here we will ensure the files are removed even if an exception comes up.
    # You will notice there is no rescue block.  We will catch exceptions in `PushmiPullyu::CLI`
    ensure
      FileUtils.rm_rf(aip_filename)
      FileUtils.rm_rf(aip_directory)
    end
  end
end

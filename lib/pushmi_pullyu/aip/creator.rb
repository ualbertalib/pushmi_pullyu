require 'archive/tar/minitar'
require 'bagit'
require 'fileutils'

class PushmiPullyu::AIP::Creator

  # Assumption: the AIP has already been downloaded

  def initialize(noid)
    @noid = noid
    @aip_directory = PushmiPullyu::AIP.aip_directory(noid)
    @aip_filename = PushmiPullyu::AIP.aip_filename(noid)
    PushmiPullyu::AIP.validate(noid)
  end

  def run(should_clean_work_directories: true)
    bag_aip
    tar_bag
    destroy_aip_directory if should_clean_work_directories
    # Return the filename of the created file
    @aip_filename
  end

  def destroy
    destroy_aip_directory
    destroy_aip_file
  end

  private

  def workdir
    File.expand_path(PushmiPullyu.options[:workdir])
  end

  def destroy_aip_file
    FileUtils.rm(@aip_filename) if File.exist?(@aip_filename)
  end

  def destroy_aip_directory
    return unless File.exist?(@aip_directory)
    PushmiPullyu.logger.info("#{@noid}: Nuking directories ...")
    FileUtils.rm_rf(@aip_directory)
  end

  def download_aip
    # Note: returns directory name for AIP
    PushmiPullyu::AIP::Downloader.new(@noid).run
  end

  def bag_aip
    bag = BagIt::Bag.new(@aip_directory)
    bag.manifest!
    raise PushmiPullyu::AIP::BagInvalid unless bag.valid?
  end

  def tar_bag
    destroy_aip_file
    Dir.chdir(workdir) do
      File.open(@aip_filename, 'wb') do |tar|
        Archive::Tar::Minitar.pack(@noid, tar)
      end
    end
  end

end

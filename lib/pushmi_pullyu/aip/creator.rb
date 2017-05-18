require 'archive/tar/minitar'
require 'bagit'
require 'pushmi_pullyu/aip'

class PushmiPullyu::AIP::Creator

  attr_reader :aip_filename, :aip_directory

  def initialize(noid)
    @noid = noid
    @aip_directory = "#{workdir}/#{@noid}"
    @aip_filename = "#{workdir}/#{@noid}.tar"
    PushmiPullyu::AIP.validate(noid)
  end

  def self.run(noid, should_skip_download: false, should_clean_work_directories: true)
    new(noid).run(should_skip_download: should_skip_download,
                  should_clean_work_directories: should_clean_work_directories)
  end

  def run(should_skip_download: false, should_clean_work_directories: true)
    download_aip unless should_skip_download
    bag_aip
    tar_bag
    destroy_aip_directory if should_clean_work_directories
    # Return the filename of the created file
    aip_filename
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
    FileUtils.rm(aip_filename) if File.exist?(aip_filename)
  end

  def destroy_aip_directory
    return unless File.exist?(aip_directory)
    PushmiPullyu.logger.info("#{@noid}: Nuking directories ...")
    FileUtils.rm_rf(aip_directory)
  end

  def download_aip
    PushmiPullyu::AIP::Downloader.run(@noid)
  end

  def bag_aip
    bag = BagIt::Bag.new(aip_directory)
    bag.manifest!
    raise PushmiPullyu::AIP::BagInvalid unless bag.valid?
  end

  def tar_bag
    destroy_aip_file
    Dir.chdir(workdir) do
      File.open(aip_filename, 'wb') do |tar|
        Archive::Tar::Minitar.pack(@noid, tar)
      end
    end
  end

end

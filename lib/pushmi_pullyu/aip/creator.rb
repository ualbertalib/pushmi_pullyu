require 'archive/tar/minitar'
require 'bagit'
require 'pushmi_pullyu/aip'

class PushmiPullyu::AIP::Creator

  attr_reader :aip_filename, :aip_directory

  def initialize(noid)
    @noid = noid
    @aip_directory = "#{workdir}/#{@noid}"
    @aip_filename = "#{workdir}/#{@noid}.tar"
  end

  def self.run(noid, skip_download: false, clean_work_directories: true)
    new(noid).run(skip_download: skip_download,
                  clean_work_directories: clean_work_directories)
  end

  def run(skip_download: false, clean_work_directories: true)
    download_aip unless skip_download
    bag_aip
    tar_bag
    destroy_aip_directory if clean_work_directories
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

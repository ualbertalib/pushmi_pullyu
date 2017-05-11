require 'pushmi_pullyu'
require 'pushmi_pullyu/aip_downloader'
require 'bagit'
require 'archive/tar/minitar'

class PushmiPullyu::AipCreator

  attr_reader :noid, :config, :logger,
              :workdir, :basedir, :tar_filename

  def initialize(noid, config = nil, logger = nil)
    @noid = noid

    @config = config || PushmiPullyu.options
    @logger = logger || PushmiPullyu.logger

    @workdir = File.expand_path(self.config[:workdir])
    @basedir = "#{workdir}/#{noid}"
    @tar_filename = "#{workdir}/#{noid}.tar"
  end

  def create_aip(skip_download: false, clean_work_directories: true)
    download_aip unless skip_download
    bag_aip
    tar_bag
    destroy_aip_directory if clean_work_directories
  end

  def cleanup
    destroy_aip_directory
    destroy_aip_file
  end

  def destroy_aip_file
    FileUtils.rm(tar_filename) if File.exist?(tar_filename)
  end

  def destroy_aip_directory
    aip_downloader.clean_directories
  end

  alias aip_filename tar_filename
  alias aip_directory basedir

  private

  def download_aip
    aip_downloader.download_objects_and_metadata
  end

  def bag_aip
    bag.manifest!
    raise PushmiPullyu::BagInvalid unless bag.valid?
  end

  def aip_downloader
    @aip_downloader ||= PushmiPullyu::AipDownloader.new(noid, config, logger)
  end

  def bag
    @bag ||= BagIt::Bag.new(basedir)
  end

  def tar_bag
    destroy_aip_file
    Dir.chdir(workdir) do
      File.open(tar_filename, 'wb') do |tar|
        Archive::Tar::Minitar.pack(noid, tar)
      end
    end
  end

end

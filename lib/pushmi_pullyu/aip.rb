require 'pushmi_pullyu'
require 'bagit'
require 'archive/tar/minitar'

module PushmiPullyu::AIP
  # Exceptions
  class BagInvalid < StandardError; end
  class NoContentFilename < StandardError; end
  class FedoraFetchError < StandardError; end
  class SolrFetchError < StandardError; end

  def self.create(noid, skip_download: false, clean_work_directories: true)
    download_aip(noid) unless skip_download
    bag_aip(noid)
    tar_bag(noid)
    destroy_aip_directory(noid) if clean_work_directories
    # Return the filename of the created file
    aip_filename(noid)
  end

  def self.destroy(noid)
    destroy_aip_directory(noid)
    destroy_aip_file(noid)
  end

  def self.aip_directory(noid)
    File.expand_path("#{PushmiPullyu.options[:workdir]}/#{noid}")
  end

  def self.aip_filename(noid)
    "#{aip_directory(noid)}/#{noid}.tar"
  end

  private

  def destroy_aip_file(noid)
    filename = aip_filename(noid)
    FileUtils.rm(filename) if File.exist?(filename)
  end

  def destroy_aip_directory(noid)
    directory = aip_directory(noid)
    return unless File.exist?(directory)
    PushmiPullyu.logger.info("#{noid}: Nuking directories ...")
    FileUtils.rm_rf(directory)
  end

  def download_aip(noid)
    PushmiPullyu::AIP::Downloader.run(noid)
  end

  def bag_aip(noid)
    bag = BagIt::Bag.new(aip_directory(noid))
    bag.manifest!
    raise PushmiPullyu::BagInvalid unless bag.valid?
  end

  def tar_bag(noid)
    destroy_aip_file(noid)
    Dir.chdir(aip_directory(noid)) do
      File.open(aip_filename(noid), 'wb') do |tar|
        Archive::Tar::Minitar.pack(noid, tar)
      end
    end
  end
end

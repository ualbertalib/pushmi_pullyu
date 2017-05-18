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
    # Return the filename of the created AIP tarball
    PushmiPullyu::AIP::Creator
      .new(noid)
      .run(skip_download: skip_download,
           clean_work_directories: clean_work_directories)
    aip_filename(noid)
  end

  def self.download(noid)
    # Return the directory of the AIP contents
    PushmiPullyu::AIP::Downloader.new(noid).run
    aip_directory(noid)
  end

  def self.aip_directory(noid)
    File.expand_path("#{PushmiPullyu.options[:workdir]}/#{noid}")
  end

  def self.aip_filename(noid)
    "#{aip_directory(noid)}/#{noid}.tar"
  end

  def self.destroy(noid)
    [aip_directory(noid), aip_filename(noid)].each do |path|
      FileUtils.rm_rf(path) if File.exist?(path)
    end
  end
end

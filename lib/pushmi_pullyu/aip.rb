require 'pushmi_pullyu'
require 'bagit'
require 'archive/tar/minitar'

module PushmiPullyu::AIP
  # Exceptions
  class BagInvalid < StandardError; end
  class NoContentFilename < StandardError; end
  class FedoraFetchError < StandardError; end
  class SolrFetchError < StandardError; end
  class WorkdirInvalid < StandardError; end
  class NoidInvalid < StandardError; end

  def self.create(noid, should_skip_download: false, should_clean_work_directories: true)
    # Note: returns the filename of the created AIP tarball
    validate(noid)
    PushmiPullyu::AIP::Creator
      .new(noid)
      .run(should_skip_download: should_skip_download,
           should_clean_work_directories: should_clean_work_directories)
  end

  def self.download(noid)
    # Note: returns the directory name of the AIP contents
    validate(noid)
    PushmiPullyu::AIP::Downloader.new(noid).run
    aip_directory(noid)
  end

  def self.aip_directory(noid)
    validate(noid)
    File.expand_path("#{PushmiPullyu.options[:workdir]}/#{sanitize_noid(noid)}")
  end

  def self.aip_filename(noid)
    validate(noid)
    File.expand_path("#{PushmiPullyu.options[:workdir]}/#{sanitize_noid(noid)}.tar")
  end

  def self.destroy(noid)
    validate(noid)
    [aip_directory(noid), aip_filename(noid)].each do |path|
      FileUtils.rm_rf(path) if File.exist?(path)
    end
  end

  def self.validate(noid)
    validate_workdir
    validate_noid(noid)
  end

  def self.validate_workdir
    raise WorkdirInvalid if PushmiPullyu.options[:workdir].to_s.empty?
  end

  def self.sanitize_noid(noid)
    # No non-ascii, and only alphanumeric, dots, dashes, and underscores
    I18n.transliterate(noid).gsub(/[^0-9A-Z\.\-]/i, '_')
  end

  def self.validate_noid(noid)
    raise NoidInvalid if sanitize_noid(noid.to_s).empty?
  end
end

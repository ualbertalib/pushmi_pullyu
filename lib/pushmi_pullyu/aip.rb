require 'fileutils'

module PushmiPullyu::AIP
  class NoidInvalid < StandardError; end

  def self.create(noid)
    validate_noid(noid)
    PushmiPullyu::AIP::Creator.new(noid).run
    aip_filename(noid)
  end

  def self.download(noid)
    validate_noid(noid)
    PushmiPullyu::AIP::Downloader.new(noid).run
    aip_directory(noid)
  end

  def self.aip_directory(noid)
    File.expand_path("#{PushmiPullyu.options[:workdir]}/#{noid}")
  end

  def self.aip_filename(noid)
    File.expand_path("#{PushmiPullyu.options[:workdir]}/#{noid}.tar")
  end

  def self.destroy(noid)
    validate_noid(noid)
    [aip_directory(noid), aip_filename(noid)].each do |path|
      FileUtils.rm_rf(path) if File.exist?(path)
    end
  end

  def self.validate_noid(noid)
    raise NoidInvalid if noid.to_s.empty?
  end
end

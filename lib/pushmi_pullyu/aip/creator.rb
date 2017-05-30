require 'minitar'
require 'bagit'
require 'fileutils'

class PushmiPullyu::AIP::Creator

  class BagInvalid < StandardError; end

  # Assumption: the AIP has already been downloaded

  def initialize(noid)
    @noid = noid
    @aip_directory = PushmiPullyu::AIP.aip_directory(noid)
    @aip_filename = PushmiPullyu::AIP.aip_filename(noid)
  end

  def run
    bag_aip
    tar_bag
  end

  private

  def bag_aip
    bag = BagIt::Bag.new(@aip_directory)
    bag.manifest!
    raise BagInvalid unless bag.valid?
  end

  def tar_bag
    Dir.chdir(workdir) do
      Minitar.pack(@noid, File.open(@aip_filename, 'wb'))
    end
  end

  def workdir
    File.expand_path(PushmiPullyu.options[:workdir])
  end

end

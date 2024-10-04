require 'minitar'
require 'bagit'
require 'fileutils'

class PushmiPullyu::AIP::Creator

  class BagInvalid < StandardError; end

  # Assumption: the AIP has already been downloaded

  def initialize(noid, aip_directory, aip_filename)
    @noid = noid
    @aip_directory = aip_directory
    @aip_filename = aip_filename
  end

  def run
    bag_aip
    tar_bag
  end

  private

  def bag_aip
    bag = BagIt::Bag.new(@aip_directory, bag_metadata)
    bag.manifest!
    raise BagInvalid unless bag.valid?
  end

  def bag_metadata
    { 'AIP-Version' => PushmiPullyu.options[:aip_version] }
  end

  def tar_bag
    # We want to change the directory to the work directory path so we get the tar file to be exactly
    # the contents of the noid directory and not the entire work directory structure. For example the noid.tar
    # contains just the noid directory instead of having the noid.tar contain the tmp directory
    # which contains the workdir directory and then finally the noid directory

    # Before we change directorys, we need to calculate the absolute filepath of our aip filename
    tar_aip_filename = File.expand_path(@aip_filename)

    Dir.chdir(PushmiPullyu.options[:workdir]) do
      File.open(tar_aip_filename, 'wb') do |tar|
        Minitar.pack(@noid, tar)
      end
    end
  end

end

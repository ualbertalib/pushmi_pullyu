require 'spec_helper'
require 'timecop'

RSpec.describe PushmiPullyu::AIP::Creator do
  let(:workdir) { 'tmp/creator_spec' }
  let(:noid) { '40fd4906-9618-41d6-8180-2880f3496520' }
  let(:aip_file) { "#{aip_folder}.tar" }
  let(:aip_folder) { "#{workdir}/#{noid}" }
  let(:creator) { PushmiPullyu::AIP::Creator.new(noid, aip_folder, aip_file) }

  before do
    allow(PushmiPullyu).to receive(:options) { { workdir: workdir, aip_version: 'lightaip-2.0' } }
    FileUtils.mkdir_p(workdir)
    FileUtils.cp_r("spec/fixtures/aip_download/#{noid}", workdir)
  end

  after do
    FileUtils.rm_rf(workdir)
    FileUtils.rm_rf(aip_file)
  end

  describe '#run' do
    it 'creates the aip' do
      # Mocked download data should exist
      expect(File.exist?(aip_folder)).to eq(true)

      # Should not exist yet
      expect(File.exist?(aip_file)).to eq(false)

      creator.run

      # Work directory exists
      expect(File.exist?(aip_folder)).to eq(true)
      # AIP exists
      expect(File.exist?(aip_file)).to eq(true)
    end

    it 'creates the correct files in the bag' do
      creator.run

      expect(File.exist?("#{aip_folder}/manifest-sha1.txt")).to eq(true)
      expect(File.exist?("#{aip_folder}/manifest-md5.txt")).to eq(true)
      expect(File.exist?("#{aip_folder}/tagmanifest-sha1.txt")).to eq(true)
      expect(File.exist?("#{aip_folder}/tagmanifest-md5.txt")).to eq(true)
      expect(File.exist?("#{aip_folder}/bagit.txt")).to eq(true)
      expect(File.exist?("#{aip_folder}/bag-info.txt")).to eq(true)

      # The downloaded AIP should have 16 directories and 11 files including the log
      # (see the downloader_spec for more elaboration about this),
      # bagging should add the above 6 files, so 30 total files/directories
      # (see also file count test in creator spec)
      expect(Dir["#{aip_folder}/**/*"].length).to eq(28)
    end

    it 'creates a correct manifest' do
      creator.run

      lines = File.readlines("#{aip_folder}/manifest-sha1.txt").map(&:strip).sort
      # 11 files in the bag
      expect(lines.length).to eq(9)

      # We can't know the sha1 of the aipcreation.log in advance (timestamps are recorded)
      sha1 = Digest::SHA1.file("#{aip_folder}/data/logs/aipcreation.log").hexdigest

      expected_file_sums = [
        '6c94fddb53b4175b7ca79b7e99f336b9a80d10bc' \
        ' data/objects/files/3cbc75f9-7bad-4d62-962e-911f911bd70e/image-sample.jpeg',
        '3a3c5fedb33fdd688d0db48c2cb64866736738de data/objects/files/8cf761ce-5222-405a-aee1-f019f860e4ba/theses.jpg',
        'ca3673d63ea097461b567a6de4f7c67dd84df21f data/objects/metadata/files_metadata/file_order.xml',
        '99a3c2f0ad344ec0784738d4530b08eba9a9c6d2' \
        ' data/objects/metadata/files_metadata/3cbc75f9-7bad-4d62-962e-911f911bd70e/file_set_metadata.n3',
        'cd54ae5cf0b425948a42f57e25a02ada6ceb806f' \
        ' data/objects/metadata/files_metadata/8cf761ce-5222-405a-aee1-f019f860e4ba/file_set_metadata.n3',
        '872c4fcae8a0f594765a20d61c99f1739dc0b549 data/objects/metadata/object_metadata.n3',
        "#{sha1} data/logs/aipcreation.log",
        '9004c767715910ba533fa2cb2ff5941244b5b284' \
        ' data/logs/files_logs/3cbc75f9-7bad-4d62-962e-911f911bd70e/content_fixity_report.n3',
        '7755131588e2f1b1a6420df72c27d8d26fe39c31' \
        ' data/logs/files_logs/8cf761ce-5222-405a-aee1-f019f860e4ba/content_fixity_report.n3'
      ].sort

      expect(lines).to eq(expected_file_sums)
    end

    it 'creates the correct bag metadata' do
      now = Time.now
      Timecop.freeze(now)

      creator.run

      lines = File.readlines("#{aip_folder}/bag-info.txt").map(&:strip).sort

      expect(lines.length).to eq(4)

      lines.each do |line|
        (key, value) = line.split(': ')
        case key
        when 'AIP-Version'
          expect(value).to eq('lightaip-2.0')
        when 'Bagging-Date'
          expect(value).to eq(now.strftime('%F'))
        else
          # Don't care about the values for these ones
          expect(['Bag-Software-Agent', 'Payload-Oxum'].include?(key)).to eq(true)
        end
      end
      Timecop.return
    end
  end
end

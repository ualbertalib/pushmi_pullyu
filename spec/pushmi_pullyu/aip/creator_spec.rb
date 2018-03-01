require 'spec_helper'

RSpec.describe PushmiPullyu::AIP::Creator do
  let(:workdir) { 'tmp/creator_spec' }
  let(:noid) { '9p2909328' }
  let(:aip_file) { "#{aip_folder}.tar" }
  let(:aip_folder) { "#{workdir}/#{noid}" }
  let(:creator) { PushmiPullyu::AIP::Creator.new(noid, aip_folder, aip_file) }

  before do
    allow(PushmiPullyu).to receive(:options) { { workdir: workdir } }
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

      # The downloaded AIP should have 5 directories and 11 files including the log,
      # bagging should add the above 6 files, so 22 total files/directories
      # (see also file count test in creator spec)
      expect(Dir["#{aip_folder}/**/*"].length).to eq(22)
    end

    it 'the created manifest is correct' do
      creator.run

      lines = File.readlines("#{aip_folder}/manifest-sha1.txt").map(&:strip).sort
      expect(lines.length).to eq(11)

      # We can't know the sha1 of the aipcreation.log in advance (timestamps are recorded)
      sha1 = Digest::SHA1.file("#{aip_folder}/data/logs/aipcreation.log").hexdigest

      expected_file_sums =
        ['e22815d17cdf02a044c25ba120360b43e4af8d28 data/thumbnails/thumbnail',
         '570b43680370ae15f458ce45192986c2f24970d9 data/objects/metadata/content_versions.n3',
         'c3769541388b1cd557185e43bb20ddf662e63546 data/logs/content_fixity_report.n3',
         "#{sha1} data/logs/aipcreation.log",
         '7c01bc0cd2fe9741ab76f2a171f1383704b60816 data/logs/content_characterization.n3',

         '5d88a0382091a3fb4fd974590b1819ec53d2f9ad '\
         'data/objects/metadata/permission_e1910293-34b3-42bb-9179-f67f37eb145e.n3',

         'fc41debcd250c808f7c90a7e7eac6eb53198e160 data/objects/metadata/object_metadata.n3',

         '422c4247a3460cfe10e082efe53d63a349a76439 '\
         'data/objects/metadata/permission_ffd40638-290a-41f7-bcb2-4e0e54fc3ffd.n3',

         'cd5825971cf2bc737b21c2e30b1d01d3ecebcfa7 '\
         'data/objects/metadata/permission_ef4319c0-2f7a-44c0-b1b5-cd650aa4a075.n3',

         '50b065c7cf19ed3e282a2a98b70f6e9429cc56ea data/objects/metadata/content_fcr_metadata.n3',
         '5eb6d58841f4196cc682ef1af3054dddacb6d40c data/objects/whatever.pdf'].sort

      puts lines
      puts ''
      puts expected_file_sums
      expect(lines).to eq(expected_file_sums)
    end
  end
end

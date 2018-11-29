require 'spec_helper'
require 'timecop'

RSpec.describe PushmiPullyu::AIP::Creator do
  let(:workdir) { 'tmp/creator_spec' }
  let(:noid) { '6841cece-41f1-4edf-ab9a-59459a127c77' }
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

      # The downloaded AIP should have 16 directories and 15 files including the log
      # (see the downloader_spec for more elaboration about this),
      # bagging should add the above 6 files, so 37 total files/directories
      # (see also file count test in creator spec)
      expect(Dir["#{aip_folder}/**/*"].length).to eq(37)
    end

    it 'creates a correct manifest' do
      creator.run

      lines = File.readlines("#{aip_folder}/manifest-sha1.txt").map(&:strip).sort
      # 15 files in the bag
      expect(lines.length).to eq(15)

      # We can't know the sha1 of the aipcreation.log in advance (timestamps are recorded)
      sha1 = Digest::SHA1.file("#{aip_folder}/data/logs/aipcreation.log").hexdigest

      expected_file_sums =
        ['c4cf94314f09bbbb13e0b7d01023b77cb3c533d9 '\
         'data/logs/files_logs/01bb1b09-974d-478b-8826-2c606a447606/content_fixity_report.n3',
         '3231d2c4345426655bdae4b9060ca3d8e422004c '\
         'data/logs/files_logs/837977d6-de61-49ea-a912-a65af5c9005e/content_fixity_report.n3',
         'c2e0cfbab6558fca5364978e9f5af098746b881f '\
         'data/logs/files_logs/856444b6-8dd5-4dfa-857d-435e354a2ead/content_fixity_report.n3',
         "#{sha1} data/logs/aipcreation.log",
         'c989727f21d6b62f17836007a8d1c59bcedb9b7a '\
         'data/objects/metadata/object_metadata.n3',
         '027e59b14f9df9cb973729d36b4f12047deb0871 '\
         'data/objects/metadata/files_metadata/file_order.xml',
         '0b9d190afaab8577424789cecd74b824cd2ae81d '\
         'data/objects/metadata/files_metadata/01bb1b09-974d-478b-8826-2c606a447606/file_set_metadata.n3',
         '94866e6490673a524888dee6acf5b85c81458a03 '\
         'data/objects/metadata/files_metadata/01bb1b09-974d-478b-8826-2c606a447606/original_file_metadata.n3',
         '442a1f64a3bd05884020a9b70fbd17752ed13e12 '\
         'data/objects/metadata/files_metadata/837977d6-de61-49ea-a912-a65af5c9005e/file_set_metadata.n3',
         '254587e16e46846e5428ba989526bc1c08ecdb47 '\
         'data/objects/metadata/files_metadata/837977d6-de61-49ea-a912-a65af5c9005e/original_file_metadata.n3',
         '7083d7bca4650aec59920e5e8b90a85667ecc5d6 '\
         'data/objects/metadata/files_metadata/856444b6-8dd5-4dfa-857d-435e354a2ead/file_set_metadata.n3',
         '30604fd556c96aac01abddf1e8b4e0369fc90ba5 '\
         'data/objects/metadata/files_metadata/856444b6-8dd5-4dfa-857d-435e354a2ead/original_file_metadata.n3',
         '9ea739a91eff6ba99e0227e3a909436d1dfd7ca7 '\
         'data/objects/files/01bb1b09-974d-478b-8826-2c606a447606/'\
         'Archive_Tar_Minitar_FileNameTooLongHjMQh5EggUDWgpsfoXfyN'\
         'GoEbvcUcN34YPpjknJhu4y8bs3qVMvBXA5A2aFBxY6EiIyxRS.jpg',
         'e559f7cea3fc307524bccdedb6d012a30b4e6c86 '\
         'data/objects/files/837977d6-de61-49ea-a912-a65af5c9005e/image-sample.jpeg',
         '49b1dc60dc20a270cf59ee04a564393bba2bf6c8 '\
         'data/objects/files/856444b6-8dd5-4dfa-857d-435e354a2ead/era-logo.png'].sort

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
        if key == 'AIP-Version'
          expect(value).to eq('lightaip-2.0')
        elsif key == 'Bagging-Date'
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

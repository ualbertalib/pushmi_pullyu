require 'spec_helper'

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
        ['6151ae34af3ae5db247763c1746aa2a6e117512f '\
         'data/logs/files_logs/01bb1b09-974d-478b-8826-2c606a447606/content_fixity_report.n3',
         'd5eeb1260efc5e32ba646b2d772222ba781ff857 '\
         'data/logs/files_logs/837977d6-de61-49ea-a912-a65af5c9005e/content_fixity_report.n3',
         '57a71d6e98782e4261f4b2f8ea9ec0c7912dc375 '\
         'data/logs/files_logs/856444b6-8dd5-4dfa-857d-435e354a2ead/content_fixity_report.n3',
         "#{sha1} data/logs/aipcreation.log",
         '93dc881a2a527c8aafe889e4151acddef16965b1 '\
         'data/objects/metadata/object_metadata.n3',
         '027e59b14f9df9cb973729d36b4f12047deb0871 '\
         'data/objects/metadata/files_metadata/file_order.xml',
         '5331e9613da278de976eae5d4d7b04a5fc39fef1 '\
         'data/objects/metadata/files_metadata/01bb1b09-974d-478b-8826-2c606a447606/file_set_metadata.n3',
         '4f2444b9702452b1a708b08d3c9c3fcbf33a4a9d '\
         'data/objects/metadata/files_metadata/01bb1b09-974d-478b-8826-2c606a447606/original_file_metadata.n3',
         '8bf3277de4af342c0e7a4f5b137d0475be120687 '\
         'data/objects/metadata/files_metadata/837977d6-de61-49ea-a912-a65af5c9005e/file_set_metadata.n3',
         '38c903d92b50cacc783db042049f7e6854b28661 '\
         'data/objects/metadata/files_metadata/837977d6-de61-49ea-a912-a65af5c9005e/original_file_metadata.n3',
         '4abb0c67c2bb476d70141ce3b3e51b7e35d9bbb2 '\
         'data/objects/metadata/files_metadata/856444b6-8dd5-4dfa-857d-435e354a2ead/file_set_metadata.n3',
         'bd1fd87d3f4117107083d988a6e80c6e6b7ed667 '\
         'data/objects/metadata/files_metadata/856444b6-8dd5-4dfa-857d-435e354a2ead/original_file_metadata.n3',
         '9ea739a91eff6ba99e0227e3a909436d1dfd7ca7 '\
         'data/objects/files/01bb1b09-974d-478b-8826-2c606a447606/theses.jpg',
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

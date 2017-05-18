require 'spec_helper'

RSpec.describe PushmiPullyu::AIP::Creator do
  let(:workdir) { 'tmp/creator_spec' }
  let(:options) do
    { workdir: workdir,
      fedora: { url: 'http://www.example.com:8983/fedora/rest',
                base_path: '/dev',
                user: 'fedoraAdmin',
                password: 'fedoraAdmin' },
      solr: { url: 'http://www.example.com:8983/solr/development' } }
  end
  let(:noid) { '9p2909328' }
  let(:aip_file) { "#{workdir}/#{noid}.tar" }
  let(:creator) { described_class.new(noid) }

  before do
    allow(PushmiPullyu.logger).to receive(:info)
    allow(PushmiPullyu).to receive(:options) { options }
    FileUtils.mkdir_p(workdir)
  end

  after do
    FileUtils.rm_rf(workdir)
    FileUtils.rm_rf(aip_file)
  end

  describe '#run' do
    it 'creates the aip, removes work directory by default' do
      VCR.use_cassette('aip_downloader_run') do
        # Should not exist yet
        expect(File.exist?('tmp/creator_spec/9p2909328')).to eq(false)
        expect(File.exist?('tmp/creator_spec/9p2909328.tar')).to eq(false)

        creator.run

        # Work directory is removed
        expect(File.exist?('tmp/creator_spec/9p2909328')).to eq(false)
        # AIP exists
        expect(File.exist?('tmp/creator_spec/9p2909328.tar')).to eq(true)
      end
    end

    it 'creates the AIP, can keep the AIP directory' do
      VCR.use_cassette('aip_downloader_run') do
        # Should not exist yet
        expect(File.exist?('tmp/creator_spec/9p2909328')).to eq(false)
        expect(File.exist?('tmp/creator_spec/9p2909328.tar')).to eq(false)

        creator.run(clean_work_directories: false)

        # Work directory is NOT removed
        expect(File.exist?('tmp/creator_spec/9p2909328')).to eq(true)
        # AIP exists
        expect(File.exist?('tmp/creator_spec/9p2909328.tar')).to eq(true)
      end
    end

    it 'creates the correct files in the bag' do
      VCR.use_cassette('aip_downloader_run') do
        creator.run(clean_work_directories: false)

        expect(File.exist?('tmp/creator_spec/9p2909328/manifest-sha1.txt')).to eq(true)
        expect(File.exist?('tmp/creator_spec/9p2909328/manifest-md5.txt')).to eq(true)
        expect(File.exist?('tmp/creator_spec/9p2909328/tagmanifest-sha1.txt')).to eq(true)
        expect(File.exist?('tmp/creator_spec/9p2909328/tagmanifest-md5.txt')).to eq(true)
        expect(File.exist?('tmp/creator_spec/9p2909328/bagit.txt')).to eq(true)
        expect(File.exist?('tmp/creator_spec/9p2909328/bag-info.txt')).to eq(true)

        # The downloaded AIP should have 5 directories and 11 files including the log,
        # bagging should add the above 6 files, so 22 total files/directories
        # (see also file count test in creator spec)
        expect(Dir['tmp/creator_spec/9p2909328/**/*'].length).to eq(22)
      end
    end

    it 'the created manifest is correct' do
      VCR.use_cassette('aip_downloader_run') do
        creator.run(clean_work_directories: false)

        # We can't know the sha1 of the aipcreation.log in advance (timestamps are recorded)
        sha1 = Digest::SHA1.file('tmp/creator_spec/9p2909328/data/logs/aipcreation.log').hexdigest

        expected_file_sums =
          ['e22815d17cdf02a044c25ba120360b43e4af8d28 data/thumbnails/thumbnail',
           '570b43680370ae15f458ce45192986c2f24970d9 data/objects/metadata/content_versions.n3',
           '9ac0e4d00d3f2613983a456fad0e53506aefe4ee data/logs/content_fixity_report.n3',
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
           '5eb6d58841f4196cc682ef1af3054dddacb6d40c data/objects/whatever.pdf']

        # Test should not expect a specific order of these lines
        num_lines = 0
        lines_matched = 0
        File.foreach('tmp/creator_spec/9p2909328/manifest-sha1.txt') do |line|
          num_lines += 1
          expected_file_sums.each do |expected|
            if line.strip == expected
              lines_matched += 1
              next
            end
          end
        end

        # 11 lines in manifest
        expect(num_lines).to eq(11)

        # 11 matches
        expect(lines_matched).to eq(11)
      end
    end
  end
end

require 'spec_helper'

RSpec.describe PushmiPullyu::FedoraObjectFetcher do
  let(:options) do
    { fedora: { url: 'http://www.example.com:8983/fedora/rest',
                base_path: '/test',
                user: 'gollum',
                password: 'iH8zH0bb1tzeZ' } }
  end
  let(:noid) { 'abc123whatever' }
  let(:fof) { described_class.new(options, noid) }
  let(:basedir) { "#{options[:workdir]}/#{noid}" }

  describe '#pairtree' do
    it 'is correct' do
      expect(fof.pairtree).to eq('ab/c1/23/wh/abc123whatever')
    end
  end

  describe '#object_url' do
    it 'sets the object URL correctly' do
      expect(fof.object_url)
        .to eq('http://www.example.com:8983/fedora/rest/test/ab/c1/23/wh/abc123whatever')
    end
  end

  describe '#download_object' do
    it 'gets an object with a correct noid' do
      allow($stdout).to receive(:puts)
      VCR.use_cassette('fof_200') do
        fof.download_object
      end
    end

    it 'fails on an object with a bad noid' do
      allow($stdout).to receive(:puts)
      VCR.use_cassette('fof_404') do
        fof.noid = 'ohnoimbad'
        fof.download_object
      end
    end
  end
end

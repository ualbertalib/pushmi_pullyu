require 'spec_helper'

RSpec.describe PushmiPullyu::SwiftDepositer do
  it 'not valid with nil arguments' do
    expect { described_class.new(nil, nil) }.to raise_error(RuntimeError)
  end

  it 'establish connection and deposit file' do
    VCR.use_cassette('swift_deposit') do
      swift_depositer = described_class.new({ username: 'test:tester',
                                              password: 'testing',
                                              tenant: 'tester',
                                              endpoint: 'http://www.example.com:8080',
                                              auth_version: 'v1.0' },
                                            'ERA')
      expect(swift_depositer).not_to be_nil
      expect(swift_depositer).to be_an_instance_of(described_class)
      expect(swift_depositer.swift_connection).to be_an_instance_of(OpenStack::Swift::Connection)

      sample_file = 'spec/fixtures/config.yml'
      deposited_file = swift_depositer.deposit_file(sample_file)

      expect(deposited_file).not_to be_nil
      expect(deposited_file).to be_an_instance_of(OpenStack::Swift::StorageObject)
      expect(deposited_file.name).to eql 'config'
      expect(deposited_file.container.name).to eql 'ERA'
      expect(deposited_file.container.swift).to be_an_instance_of(OpenStack::Swift::Connection)
    end
  end
end

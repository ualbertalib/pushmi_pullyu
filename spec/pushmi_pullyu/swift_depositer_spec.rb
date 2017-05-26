require 'spec_helper'

RSpec.describe PushmiPullyu::SwiftDepositer do
  it 'deposits new file' do
    VCR.use_cassette('swift_new_deposit') do
      swift_depositer = PushmiPullyu::SwiftDepositer.new(username: 'test:tester',
                                                         password: 'testing',
                                                         tenant: 'tester',
                                                         endpoint: 'http://www.example.com:8080',
                                                         auth_version: 'v1.0')
      sample_file = 'spec/fixtures/config.yml'

      deposited_file = swift_depositer.deposit_file(sample_file, 'ERA')

      expect(deposited_file).not_to be_nil
      expect(deposited_file).to be_an_instance_of(OpenStack::Swift::StorageObject)
      expect(deposited_file.name).to eql 'config'
      expect(deposited_file.container.name).to eql 'ERA'
    end
  end

  it 'updates existing file' do
    VCR.use_cassette('swift_update_deposit') do
      swift_depositer = PushmiPullyu::SwiftDepositer.new(username: 'test:tester',
                                                         password: 'testing',
                                                         tenant: 'tester',
                                                         endpoint: 'http://www.example.com:8080',
                                                         auth_version: 'v1.0')

      sample_file = 'spec/fixtures/config_with_envs.yml'

      # Deposits file twice, expects it only adds it once
      expect do
        swift_depositer.deposit_file(sample_file, 'ERA')
        swift_depositer.deposit_file(sample_file, 'ERA')
      end.to change { swift_depositer.swift_connection.container('ERA').count.to_i }.by(1)
    end
  end
end

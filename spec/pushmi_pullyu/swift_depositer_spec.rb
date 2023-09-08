require 'spec_helper'

RSpec.describe PushmiPullyu::SwiftDepositer do
  describe '#deposit_file' do
    it 'deposits new file' do
      sample_file = 'spec/fixtures/config.yml'

      VCR.use_cassette('swift_new_deposit') do
        swift_depositer = PushmiPullyu::SwiftDepositer.new(username: 'test:tester',
                                                           password: 'testing',
                                                           auth_url: 'http://127.0.0.1:8080/auth/v1.0')

        deposited_file = swift_depositer.deposit_file(sample_file, 'ERA')

        expect(deposited_file).not_to be_nil
        expect(deposited_file).to be_an_instance_of(OpenStack::Swift::StorageObject)
        expect(deposited_file.name).to eql 'config'
        expect(deposited_file.container.name).to eql 'ERA'
        expect(deposited_file.metadata['project']).to eql 'ERA'
        expect(deposited_file.metadata['project-id']).to eql 'config'
        expect(deposited_file.metadata['aip-version']).to eql '1.0'
        expect(deposited_file.metadata['promise']).to eql 'bronze'
      end
    end

    it 'updates existing file' do
      sample_file = 'spec/fixtures/config_with_envs.yml'

      VCR.use_cassette('swift_update_deposit') do
        swift_depositer = PushmiPullyu::SwiftDepositer.new(username: 'test:tester',
                                                           password: 'testing',
                                                           auth_url: 'http://127.0.0.1:8080/auth/v1.0')

        # Deposits file twice, check that it only gets added once to the container
        expect do
          first_deposit = swift_depositer.deposit_file(sample_file, 'ERA')
          second_deposit = swift_depositer.deposit_file(sample_file, 'ERA')

          expect(first_deposit.name).to eq(second_deposit.name)
          expect(first_deposit.container.name).to eq(second_deposit.container.name)
        end.to change { swift_depositer.swift_connection.container('ERA').count.to_i }.by(1)
      end
    end
  end
end

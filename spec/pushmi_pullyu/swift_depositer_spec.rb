require 'spec_helper'

RSpec.describe PushmiPullyu::SwiftDepositer do
  describe '#deposit_file' do
    it 'deposits new file' do
      sample_file = 'spec/fixtures/config.yml'

      VCR.use_cassette('swift_new_deposit') do
        swift_depositer = PushmiPullyu::SwiftDepositer.new(username: 'test:tester',
                                                           password: 'testing',
                                                           tenant: 'tester',
                                                           auth_url: 'http://127.0.0.1:8080/auth/v1.0')

        expect(swift_depositer.inspect).to include '@retry_auth=true' # retry_auth isn't exposed                                                           

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
                                                           tenant: 'tester',
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

    it 'authenticates against v3' do
      VCR.use_cassette('swift_auth_v3') do
        swift_depositer = PushmiPullyu::SwiftDepositer.new(
          username: 'era_olrc_user',
          password: 'era_olrc_user_password',
          auth_url: 'https://olrc2auth.scholarsportal.info/v3/',
          user_domain: 'alberta',
          container: 'era',
          project_name: 'demo',
          auth_method: 'password',
          service_type: 'object-store',
          auth_version: 'v3'
        )
        expect(swift_depositer).not_to be_nil
        # rubocop:disable Layout/LineLength
        expect(swift_depositer.swift_connection.connection.authtoken).to eq('gAAAAABl8hYAouKZJLkt8NDmuA2NjA1zOasGOAX-b2MfKpjiM_kf8sZHe42ipcs6Vb-57-aATajbTg54wIwhNhl2HKRfz5_rKfSJ0PnBQNFCVd4bKrdC0pHzoJMn9hkAa2tjBkqppBcMayvfqz-Ppxn0USnHw0z9zLLKDxGbRZwyhDJDhGOcIZg')
        # rubocop:enable Layout/LineLength
      end
    end
  end
end

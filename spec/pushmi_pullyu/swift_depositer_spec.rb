require 'spec_helper'

RSpec.describe PushmiPullyu::SwiftDepositer do
  it 'not valid without arguments' do
    expect { described_class.new }.to raise_error(ArgumentError)
  end

  it 'not valid with nil arguments' do
    expect { described_class.new(nil, nil) }.to raise_error(RuntimeError)
  end

  it 'valid connection established' do
    swift_connection = described_class.new({ username: 'test:tester',
                                             password: 'testing',
                                             tenant: 'tester',
                                             endpoint: 'http://127.0.0.1:8080',
                                             auth_version: 'v1.0' },
                                           'ERA')
    expect(swift_connection).not_to be_nil
    expect(swift_connection).to be_an_instance_of(described_class)
    expect(swift_connection.swift_connection).to be_an_instance_of(OpenStack::Swift::Connection)
  end
end

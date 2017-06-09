require 'digest/md5'
require 'openstack'

class PushmiPullyu::SwiftDepositer

  attr_reader :swift_connection

  def initialize(connection)
    @swift_connection = OpenStack::Connection.create(
      username: connection[:username],
      api_key: connection[:password],
      auth_method: 'password',
      auth_url: "#{connection[:endpoint]}/auth/#{connection[:auth_version]}",
      authtenant_name: connection[:tenant],
      service_type: 'object-store'
    )
  end

  def deposit_file(file_name, swift_container)
    file_base_name = File.basename(file_name, '.*')

    checksum = Digest::MD5.file(file_name).hexdigest

    era_container = swift_connection.container(swift_container)

    object_exists = era_container.object_exists?(file_base_name)

    # Add swift metadata with in accordance to AIP spec:
    # https://docs.google.com/document/d/154BqhDPAdGW-I9enrqLpBYbhkF9exX9lV3kMaijuwPg/edit#
    swift_metadata = {
      project: 'ERA',
      project_id: file_base_name,
      promise: 'bronze',
      aip_version: '1.0'
    }

    # ruby-openstack wants all keys of the metadata to be named like "X-Object-Meta-{{Key}}", so update them
    swift_metadata.transform_keys! { |key| "X-Object-Meta-#{key}" }

    # creatre file metadata
    file_metadata = { 'etag' => checksum,
                      'content-type' => 'application/x-tar' }.merge(swift_metadata)

    # create new file
    return era_container.create_object(file_base_name, file_metadata, File.open(file_name)) unless object_exists

    # update existing one
    deposited_file = era_container.object(file_base_name)
    deposited_file.write(File.open(file_name), file_metadata)

    deposited_file
  end

end

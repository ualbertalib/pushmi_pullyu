require 'digest/md5'
require 'openstack'

class PushmiPullyu::SwiftDepositer

  attr_reader :swift_connection

  def initialize(connection)
    @swift_connection = OpenStack::Connection.create(
      username: connection[:username],
      api_key: connection[:password],
      auth_method: 'password',
      auth_url: connection[:auth_url],
      project_name: connection[:project_name],
      project_domain_name: connection[:project_domain_name],
      authtenant_name: connection[:tenant],
      service_type: 'object-store'
    )
  end

  def deposit_file(file_name, swift_container)
    file_base_name = File.basename(file_name, '.*')

    checksum = Digest::MD5.file(file_name).hexdigest

    era_container = swift_connection.container(swift_container)

    # Add swift metadata with in accordance to AIP spec:
    # https://docs.google.com/document/d/154BqhDPAdGW-I9enrqLpBYbhkF9exX9lV3kMaijuwPg/edit#
    metadata = {
      project: 'ERA',
      project_id: file_base_name,
      promise: 'bronze',
      aip_version: '1.0'
    }

    # ruby-openstack wants all keys of the metadata to be named like "X-Object-Meta-{{Key}}", so update them
    metadata.transform_keys! { |key| "X-Object-Meta-#{key}" }

    # ruby-openstack expects the header hash in different structure for write vs create_object methods
    # details see: https://github.com/ualbertalib/pushmi_pullyu/issues/105
    if era_container.object_exists?(file_base_name)
      # temporary solution until fixed in upstream:
      # for update: construct hash for key/value pairs as strings, 
      # and metadata as additional key/value string pairs in the hash
      headers = { 'etag' => checksum,
                  'content-type' => 'application/x-tar' }.merge(metadata)
      deposited_file = era_container.object(file_base_name)
      deposited_file.write(File.open(file_name), headers)
    else
      # for creating new: construct hash with symbols as keys, add metadata as a hash within the header hash
      headers = { etag: checksum,
                  content_type:  'application/x-tar',
                  metadata: metadata }
      deposited_file = era_container.create_object(file_base_name, headers, File.open(file_name))
    end

    deposited_file
  end

end

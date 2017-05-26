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

    hash = Digest::MD5.file(file_name).hexdigest

    era_container = swift_connection.container(swift_container)

    deposited_file = if era_container.object_exists?(file_base_name)
                       era_container.object(file_base_name)
                     else
                       era_container.create_object(file_base_name)
                     end
    deposited_file.write(File.open(file_name), 'etag' => hash, 'content-type' => 'application/x-tar')

    deposited_file
  end

end

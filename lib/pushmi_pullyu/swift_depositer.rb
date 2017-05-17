require 'openstack'

class PushmiPullyu::SwiftDepositer

  attr_reader :swift_connection, :swift_container

  def initialize(connection, container)
    raise 'conection can not be nil' if connection.nil?
    raise 'container can not be nil' if container.nil?

    endpoint     = connection[:endpoint]
    auth_version = connection[:auth_version]

    @swift_connection = OpenStack::Connection.create(username: connection[:username],
                                                     api_key: connection[:password],
                                                     auth_method: 'password',
                                                     auth_url: "#{endpoint}/auth/#{auth_version}",
                                                     authtenant_name: connection[:tenant],
                                                     service_type: 'object-store')
    @swift_container = container
  end

  def deposit_file(file_name)
    # check if file exists
    raise "File #{file_name} does not exist" unless File.file?(file_name)
    file_base_name = File.basename(file_name, '.*')

    # calculate file hash
    hash = Digest::MD5.file(file_name).hexdigest

    # get container object
    era_container = @swift_connection.container(@swift_container)

    deposited_file = if era_container.object_exists?(file_base_name)
                       PushmiPullyu.logger.debug(
                         "File object #{@swift_container}/#{file_base_name} already in the swift, updating content"
                       )
                       era_container.object(file_base_name)
                     else
                       PushmiPullyu.logger.debug(
                         "Creating new file object #{@swift_container}/#{file_base_name} in the swift"
                       )
                       era_container.create_object(file_base_name)
                     end
    deposited_file.write(File.open(file_name), {'etag' => hash, 'content-type' => 'application/x-tar' } )

    deposited_file
  end

end

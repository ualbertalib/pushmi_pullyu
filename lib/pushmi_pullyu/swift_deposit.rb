require 'openstack'

class PushmiPullyu::SwiftDepositer

  def initialize(connection: nil, container: nil)
    raise 'conection can not be nil' if connection.nil?
    raise 'container can not be nil' if container.nil?

    user         = connection[:username]
    pass         = connection[:password]
    tenant       = connection[:tenant]
    endpoint     = connection[:endpoint]
    service_type  = 'object-store'
    auth_method   = 'password'
    auth_version = connection[:auth_version]

    @swift_connection = OpenStack::Connection.create(username: user,
                                                     api_key: pass,
                                                     auth_method: auth_method,
                                                     auth_url: "#{endpoint}/auth/#{auth_version}",
                                                     authtenant_name: tenant,
                                                     service_type: service_type)
    @swift_container = container
    @logger = PushmiPullyu.logger
  end

  def deposit_file(file_name)
    # check if file exists
    raise "File #{file_name} does not exist" unless File.file?(file_name)
    file_base_name = File.basename(file_name)

    # calculate file hash
    hash = Digest::MD5.file(file_name).hexdigest

    # check that container exits
    raise "Container #{@swift_container} does not exist" unless @swift_connection.container_exists?(@swift_container)

    # get container object
    era_container = @swift_connection.container(@swift_container)

    if era_container.object_exists?(file_base_name)
      # if file already exists, update it with new data
      @logger.debug("File object #{@swift_container}/#{file_base_name} aleary in the swift, updating content")
      deposited_file = era_container.object(file_base_name)
      deposited_file.write(File.open(file_name),
                           etag: hash, content_type: 'application/octet-stream')
    else
      # create new deposit file
      @logger.debug("Creating new file object #{@swift_container}/#{file_base_name} in the swift")
      deposited_file = era_container.create_object(file_base_name,
                                                   { etag: hash, content_type: 'application/octet-stream' },
                                                   File.open(file_name))
    end

    deposited_file
  end

end

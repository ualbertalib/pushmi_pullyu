require 'openstack'

class PushmiPullyu::SwiftDepositer

  def initialize(connection: nil, container: nil )

    if(connection.nil? )
      raise "conection can not be nil"
    end

    if(container.nil? )
      raise "container can not be nil"
    end

     user         = connection[:username]
     pass         = connection[:password]
     tenant       = connection[:tenant]
     endpoint     = connection[:endpoint]
     serviceType  = "object-store"
     authMethod   = "password"
     auth_version = connection[:auth_version]

     @swiftConnection = OpenStack::Connection.create({
                                           :username => user,
                                           :api_key=>pass,
                                           :auth_method=>authMethod,
                                           :auth_url=>"#{endpoint}/auth/#{auth_version}",
                                           :authtenant_name =>tenant,
                                           :service_type=>serviceType})
     @swiftContainer = container
     @logger = PushmiPullyu.logger
  end


  def depositFile (fileName)

    #check if file exists
    if !File.file?(fileName)
      raise "File #{fileName} does not exist"
    end
    fileBaseName=File.basename(fileName)

    # calculate file hash
    hash = Digest::MD5.file(fileName).hexdigest

    #check that container exits
    if ! @swiftConnection.container_exists?(@swiftContainer)
      raise "Container #{@swiftContainer} does not exist"
    end

    # get container object
    eraContainer=@swiftConnection.container(@swiftContainer)

    if eraContainer.object_exists?(fileBaseName)
      #if file already exists, update it with new data
      @logger.debug("File object #{@swiftContainer}/#{fileBaseName} aleary in the swift, updating content")
      depositedFile=eraContainer.object(fileBaseName)
      depositedFile.write(File.open(fileName),
                          {:etag=>hash, :content_type=>"application/octet-stream"})
    else
      #create new deposit file
      @logger.debug("Creating new file object #{@swiftContainer}/#{fileBaseName} in the swift")
      depositedFile=eraContainer.create_object(fileBaseName,
                                               {:etag=>hash, :content_type=>"application/octet-stream"},
                                               File.open(fileName))
    end

    return depositedFile

  end

end

require 'net/http'

class PushmiPullyu::AIP::OwnerEmailEditor

  OWNER_PREDICATE = RDF::URI('http://purl.org/ontology/bibo/owner').freeze

  class NoOwnerPredicate < StandardError; end

  def initialize(rdf_string)
    @document = rdf_string
  end

  def run
    ensure_database_connection

    is_modified = false
    prefixes = nil
    # Read once to load prefixes (the @things at the top of an n3 file)
    RDF::N3::Reader.new(input = @document) do |reader|
      reader.each_statement { |_statement| }
      prefixes = reader.prefixes
    end
    new_body = RDF::N3::Writer.buffer(prefixes: prefixes) do |writer|
      RDF::N3::Reader.new(input = @document) do |reader|
        reader.each_statement do |statement|
          if statement.predicate == OWNER_PREDICATE
            user = PushmiPullyu::AIP::User.find(statement.object.to_i)
            writer << [statement.subject, statement.predicate, user.email]
            is_modified = true
          else
            writer << statement
          end
        end
      end
    end
    return new_body if is_modified
    raise NoOwnerPredicate
  end

  private

  def ensure_database_connection
    return if ActiveRecord::Base.connected?
    ActiveRecord::Base.establish_connection(database_configuration)
  end

  def database_configuration
    # Config either from URL, or with more granular options (the later taking precedence)
    config = {}
    uri = URI.parse(PushmiPullyu.options[:database][:url])
    config[:adapter] = PushmiPullyu.options[:database][:adaptor] || uri.scheme
    config[:host] = PushmiPullyu.options[:database][:host] || uri.host
    config[:database] = PushmiPullyu.options[:database][:database] || uri.path.split('/')[1].to_s
    config[:username] = PushmiPullyu.options[:database][:username] || uri.user
    config[:password] = PushmiPullyu.options[:database][:password] || uri.password
    params = CGI.parse(uri.query || '')
    config[:encoding] = PushmiPullyu.options[:database][:encoding] || params['encoding'].to_a.first
    config[:pool] = PushmiPullyu.options[:database][:pool] || params['pool'].to_a.first
    config
  end

end

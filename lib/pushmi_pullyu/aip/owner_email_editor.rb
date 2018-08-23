require 'net/http'

class PushmiPullyu::AIP::OwnerEmailEditor

  OWNER_PREDICATE = RDF::URI('http://purl.org/ontology/bibo/owner').freeze

  class NoOwnerPredicate < StandardError; end

  def initialize(rdf_string)
    @document = rdf_string
  end

  def run
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
end


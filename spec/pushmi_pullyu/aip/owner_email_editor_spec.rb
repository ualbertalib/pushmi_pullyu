require 'spec_helper'

RSpec.describe PushmiPullyu::AIP::OwnerEmailEditor do
  let(:noid) { '6841cece-41f1-4edf-ab9a-59459a127c77' }
  let(:fedora_fetcher) { PushmiPullyu::AIP::FedoraFetcher.new(noid) }
  let(:workdir) { 'tmp/owner_email_editor_spec' }
  let(:download_path) { "#{workdir}/newobject.n3" }
  let(:output_path) { "#{workdir}/modifiedobject.n3" }

  before do
    FileUtils.mkdir_p(workdir)
    allow(PushmiPullyu).to receive(:options).and_return(
      fedora: { url: 'http://www.example.com:8080/fcrepo/rest',
                base_path: '/dev',
                user: 'gollum',
                password: 'iH8zH0bb1tzeZ' },
      # This next one isn't really used, see mock of PushmiPullyu::AIP::User.find below
      database: { url: 'postgresql://jupiter:mysecretpassword@127.0.0.1/jupiter_test?pool=5' }
    )
    allow(PushmiPullyu::AIP::User)
      .to receive(:find).with(2705).and_return(OpenStruct.new(email: 'admin@example.com'))
  end

  after do
    FileUtils.rm_rf(workdir)
  end

  it 'edits the owner triple, but keeps everything else unchanged' do
    VCR.use_cassette('aip_downloader_run') do
      expect(fedora_fetcher.download_object(download_path)).to eq(true)
    end

    input_rdf = File.read(download_path)
    output_rdf = PushmiPullyu::AIP::OwnerEmailEditor.new(input_rdf).run

    # It bothers me that I have to load a graph from file/URI, but can't from a string
    File.open(output_path, 'w') { |file| file.write(output_rdf) }
    input_graph = RDF::Graph.load(download_path)
    output_graph = RDF::Graph.load(output_path)

    expect(input_graph.count).to eq(54)
    expect(output_graph.count).to eq(54)

    statements_matched = 0
    input_graph.each_statement do |input_statement|
      if input_statement.predicate == RDF::URI('http://purl.org/ontology/bibo/owner')
        # If it's the owner predicate, it has been changed ...
        output_graph.query(subject: input_statement.subject,
                           predicate: input_statement.predicate) do |output_statement|
          statements_matched += 1
          expect(input_statement.object.to_i).to eq(2705)
          expect(output_statement.object.to_s).to eq('admin@example.com')
        end
      else
        # ... otherwise an identical statement is in the output
        output_graph.query(subject: input_statement.subject,
                           predicate: input_statement.predicate,
                           object: input_statement.object) do |_output_statement|
          statements_matched += 1
        end
      end
    end

    expect(statements_matched).to eq(54)
  end
end

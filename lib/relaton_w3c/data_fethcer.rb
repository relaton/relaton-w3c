require "rdf"
require "linkeddata"
require "sparql"
require "mechanize"
require "relaton_w3c/data_parser"

module RelatonW3c
  class DataFetcher
    USED_TYPES = %w[WD NOTE PER PR REC CR].freeze

    attr_reader :data, :group_names

    #
    # Data fetcher initializer
    #
    # @param [String] output directory to save files
    # @param [String] format format of output files (xml, yaml, bibxml)
    #
    def initialize(output, format)
      @output = output
      @format = format
      @ext = format.sub(/^bib/, "")
      dir = File.dirname(File.expand_path(__FILE__))
      @group_names = YAML.load_file(File.join(dir , "workgroups.yaml"))
      @data = RDF::Repository.load("http://www.w3.org/2002/01/tr-automation/tr.rdf")
      @files = []
    end

    #
    # Initialize fetcher and run fetch
    #
    # @param [Strin] output directory to save files, default: "data"
    # @param [Strin] format format of output files (xml, yaml, bibxml), default: yaml
    #
    def self.fetch(output: "data", format: "yaml")
      t1 = Time.now
      puts "Started at: #{t1}"
      FileUtils.mkdir_p output unless Dir.exist? output
      new(output, format).fetch
      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    end

    #
    # Parse documents
    #
    def fetch
      query.each { |sl| save_doc DataParser.parse(sl, self) }
      Dir[File.expand_path("../../data/*", __dir__)].each do |file|
        xml = File.read file, encoding: "UTF-8"
        save_doc BibXMLParser.parse(xml)
      end
    end

    #
    # Query RDF source for documents
    #
    # @return [RDF::Query::Solutions] query results
    #
    def query # rubocop:disable Metrics/MethodLength
      sse = SPARQL.parse(%(
        PREFIX : <http://www.w3.org/2001/02pd/rec54#>
        PREFIX dc: <http://purl.org/dc/elements/1.1/>
        PREFIX doc: <http://www.w3.org/2000/10/swap/pim/doc#>
        # PREFIX mat: <http://www.w3.org/2002/05/matrix/vocab#>
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        SELECT ?link ?title ?date
        WHERE {
          ?link dc:title ?title ; dc:date ?date . # ; doc:versionOf ?version_of .
        }
      ))
      data.query sse
    end

    #
    # Save document to file
    #
    # @param [RelatonW3c::W3cBibliographicItem, nil] bib bibliographic item
    #
    def save_doc(bib) # rubocop:disable Metrics/MethodLength
      return unless bib

      c = case @format
          when "xml" then bib.to_xml(bibdata: true)
          when "yaml" then bib.to_hash.to_yaml
          else bib.send("to_#{@format}")
          end
      file = file_name(bib)
      if @files.include? file
        warn "File #{file} already exists. Document: #{bib.docnumber}"
      else
        @files << file
      end
      File.write file, c, encoding: "UTF-8"
    end

    #
    # Generate file name
    #
    # @param [RelatonW3c::W3cBibliographicItem] bib bibliographic item
    #
    # @return [String] file name
    #
    def file_name(bib)
      name = bib.docnumber.gsub(/[\s,:\/]/, "_").squeeze("_").upcase
      File.join @output, "#{name}.#{@ext}"
    end
  end
end

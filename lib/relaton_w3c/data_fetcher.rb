require "rdf"
require "linkeddata"
require "sparql"
require "mechanize"
require "relaton_w3c/data_parser"

module RelatonW3c
  class DataFetcher
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
      @group_names = YAML.load_file(File.join(dir, "workgroups.yaml"))
      @index = DataIndex.create_from_file
    end

    #
    # Initialize fetcher and run fetch
    #
    # @param [String] source source name "w3c-tr-archive" or "w3c-rdf"
    # @param [Strin] output directory to save files, default: "data"
    # @param [Strin] format format of output files (xml, yaml, bibxml), default: yaml
    #
    def self.fetch(source, output: "data", format: "yaml")
      t1 = Time.now
      puts "Started at: #{t1}"
      FileUtils.mkdir_p output
      new(output, format).fetch source
      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    end

    #
    # Parse documents
    #
    # @param [String] source source name "w3c-tr-archive" or "w3c-rdf"
    #
    def fetch(source) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      each_dataset(source) do |rdf|
        %i[versioned unversioned].each do |type|
          send("query_#{type}_docs", rdf).each do |sl|
            bib = DataParser.parse(rdf, sl, self)
            add_has_edition_relation(bib) if type == :unversioned
            save_doc bib
          rescue StandardError => e
            link = sl.respond_to?(:link) ? sl.link : sl.version_of
            warn "Error: document #{link} #{e.message}"
            warn e.backtrace.join("\n")
          end
        end
      end
      @index.sort!.save
    end

    #
    # Add hasEdition relations form previous parsed document
    #
    # @param [RelatonW3c::W3cBibliographicItem] bib bibligraphic item
    #
    def add_has_edition_relation(bib) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
      file = file_name bib.docnumber
      if File.exist? file
        item = send "read_#{@format}", file
        item.relation.each do |r1|
          r1.type = "hasEdition" if r1.type == "instance"
          same_edition = bib.relation.detect { |r2| same_edition?(r1, r2) }
          bib.relation << r1 unless same_edition
        end
      end
      bib.relation.select { |r| r.type == "hasEdition" }
        .max_by { |r| r.bibitem.id.match(/(?<=-)\d{8}$/).to_s }&.type = "instance"
    end

    #
    # Read XML file
    #
    # @param [String] file file name
    #
    # @return [RelatonW3c::W3cBibliographicItem] bibliographic item
    #
    def read_xml(file)
      XMLParser.from_xml(File.read(file, encoding: "UTF-8"))
    end

    #
    # Read YAML file
    #
    # @param [String] file file name
    #
    # @return [RelatonW3c::W3cBibliographicItem] bibliographic item
    #
    def read_yaml(file)
      hash = YAML.load_file(file)
      W3cBibliographicItem.from_hash(hash)
    end

    #
    # Read BibXML file
    #
    # @param [String] file file name
    #
    # @return [RelatonW3c::W3cBibliographicItem] bibliographic item
    #
    def read_bibxml(file)
      BibXMLParser.parse File.read(file, encoding: "UTF-8")
    end

    #
    # Compare two relations
    #
    # @param [RelatonW3c::W3cBibliographicItem] rel1 relation 1
    # @param [RelatonW3c::W3cBibliographicItem] rel2 relation 2
    #
    # @return [Boolean] true if relations are same
    #
    def same_edition?(rel1, rel2)
      return false unless rel1.type == "hasEdition" && rel1.type == rel2.type

      ids1 = rel1.bibitem.docidentifier.map(&:id)
      ids2 = rel2.bibitem.docidentifier.map(&:id)
      (ids1 & ids2).any?
    end

    #
    # Yield fetching for each dataset
    #
    # @param [String] source source name "w3c-tr-archive" or "w3c-rdf"
    #
    # @yield [RDF::Repository] RDF repository
    #
    def each_dataset(source, &_block) # rubocop:disable Metrics/MethodLength
      case source
      when "w3c-tr-archive"
        Dir["w3c-tr-archive/*.rdf"].map do |f|
          @files = []
          yield RDF::Repository.load(f)
        end
      when "w3c-rdf"
        @files = []
        rdf = RDF::Repository.load("http://www.w3.org/2002/01/tr-automation/tr.rdf")
        yield rdf
        # parse_static_dataset
      end
    end

    #
    # Parse static dataset
    #
    # def parse_static_dataset
    #   Dir[File.expand_path("../../data/*", __dir__)].each do |file|
    #     xml = File.read file, encoding: "UTF-8"
    #     save_doc BibXMLParser.parse(xml), warn_duplicate: false
    #   rescue StandardError => e
    #     warn "Error: document #{file} #{e.message}"
    #     warn e.backtrace.join("\n")
    #   end
    # end

    #
    # Query RDF source for versioned documents
    #
    # @return [RDF::Query::Solutions] query results
    #
    def query_versioned_docs(rdf)
      sse = SPARQL.parse(%(
        PREFIX : <http://www.w3.org/2001/02pd/rec54#>
        PREFIX dc: <http://purl.org/dc/elements/1.1/>
        PREFIX doc: <http://www.w3.org/2000/10/swap/pim/doc#>
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        SELECT ?link ?title ?date
        WHERE { ?link dc:title ?title ; dc:date ?date . }
      ))
      rdf.query sse
    end

    #
    # Query RDF source for unversioned documents
    #
    # @return [Array<RDF::Query::Solution>] query results
    #
    def query_unversioned_docs(rdf)
      sse = SPARQL.parse(%(
        PREFIX doc: <http://www.w3.org/2000/10/swap/pim/doc#>
        SELECT ?version_of
        WHERE {
          ?link doc:versionOf ?version_of .
          FILTER ( isURI(?link) && isURI(?version_of) && ?link != ?version_of )
        }
      ))
      rdf.query(sse).uniq { |s| s.version_of.to_s.sub(/^https?:\/\//, "").sub(/\/$/, "") }
    end

    #
    # Save document to file
    #
    # @param [RelatonW3c::W3cBibliographicItem, nil] bib bibliographic item
    #
    def save_doc(bib, warn_duplicate: true) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return unless bib

      c = case @format
          when "xml" then bib.to_xml(bibdata: true)
          when "yaml" then bib.to_hash.to_yaml
          else bib.send("to_#{@format}")
          end
      # id = bib.docidentifier.detect(&:primary)&.id || bib.formattedref.content
      file = file_name(bib.docnumber)
      if @files.include?(file)
        warn "File #{file} already exists. Document: #{bib.docnumber}" if warn_duplicate
      else
        @index.add bib.docnumber, file
        @files << file
        File.write file, c, encoding: "UTF-8"
      end
    end

    #
    # Generate file name
    #
    # @param [String] id document id
    #
    # @return [String] file name
    #
    def file_name(id)
      name = id.sub(/^W3C\s/, "").gsub(/[\s,:\/+]/, "_").squeeze("_").downcase
      File.join @output, "#{name}.#{@ext}"
    end
  end
end

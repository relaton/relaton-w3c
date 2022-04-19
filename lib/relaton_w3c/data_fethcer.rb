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
      @data = RDF::Repository.load("http://www.w3.org/2002/01/tr-automation/tr.rdf")
      @files = []
      @index = DataIndex.new
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
    def fetch # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      query_versioned_docs.each do |sl|
        save_doc DataParser.parse(sl, self)
      rescue StandardError => e
        warn "Error: document #{sl.link} #{e.message}"
        warn e.backtrace.join("\n")
      end
      query_unversioned_docs.each do |sl|
        save_doc DataParser.parse(sl, self)
      rescue StandardError => e
        warn "Error: document #{sl.version_of} #{e.message}"
        warn e.backtrace.join("\n")
      end
      Dir[File.expand_path("../../data/*", __dir__)].each do |file|
        xml = File.read file, encoding: "UTF-8"
        save_doc BibXMLParser.parse(xml), warn_duplicate: false
      rescue StandardError => e
        warn "Error: document #{file} #{e.message}"
        warn e.backtrace.join("\n")
      end
      @index.sort!.save
    end

    #
    # Create index file
    #
    # def create_index
    #   index_file = "index-w3c.yaml"
    #   index_yaml = @index.sort do |a, b|
    #     compare_index_items a, b
    #   end.to_yaml
    #   File.write index_file, index_yaml, encoding: "UTF-8"
    # end

    #
    # Compare index items
    #
    # @param [Hash] aid first item
    # @param [Hash] bid second item
    #
    # @return [Integer] comparison result
    #
    # def compare_index_items(aid, bid) # rubocop:disable Metrics/AbcSize
    #   ret = aid[:code] <=> bid[:code]
    #   ret = stage_weight(bid[:stage]) <=> stage_weight(aid[:stage]) if ret.zero?
    #   ret = date_weight(bid[:date]) <=> date_weight(aid[:date]) if ret.zero?
    #   # ret = aid[:type] <=> bid[:type] if ret.zero?
    #   ret
    # end

    #
    # Weight of stage
    #
    # @param [String, nil] stage stage
    #
    # @return [Integer] weight
    #
    # def stage_weight(stage)
    #   return DataParser::STAGES.size if stage.nil?

    #   DataParser::STAGES.keys.index(stage)
    # end

    #
    # Weight of date
    #
    # @param [String] date date
    #
    # @return [String] weight
    #
    # def date_weight(date)
    #   return "99999999" if date.nil?

    #   date
    # end

    #
    # Query RDF source for documents
    #
    # @return [RDF::Query::Solutions] query results
    #
    def query_versioned_docs # rubocop:disable Metrics/MethodLength
      sse = SPARQL.parse(%(
        PREFIX : <http://www.w3.org/2001/02pd/rec54#>
        PREFIX dc: <http://purl.org/dc/elements/1.1/>
        PREFIX doc: <http://www.w3.org/2000/10/swap/pim/doc#>
        # PREFIX mat: <http://www.w3.org/2002/05/matrix/vocab#>
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        SELECT ?link ?title ?date ?version_of
        WHERE {
          ?link dc:title ?title ; dc:date ?date ; doc:versionOf ?version_of .
        }
      ))
      data.query sse
    end

    def query_unversioned_docs
      sse = SPARQL.parse(%(
        PREFIX doc: <http://www.w3.org/2000/10/swap/pim/doc#>
        SELECT ?version_of
        WHERE { ?x doc:versionOf ?version_of . }
      ))
      data.query(sse).uniq &:version_of
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

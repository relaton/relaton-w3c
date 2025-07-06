require "w3c_api"
require_relative "rate_limit_handler"
require_relative "data_parser"

module RelatonW3c
  class DataFetcher
    include RelatonW3c::RateLimitHandler

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
      @files = Set.new
      @fetched_urls = {}
      @index = DataIndex.create_from_file
      @index1 = Relaton::Index.find_or_create :W3C, file: "index1.yaml"
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
      FileUtils.mkdir_p output
      new(output, format).fetch
      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    end

    def client
      @client ||= W3cApi::Client.new
    end

    #
    # Parse documents
    #
    def fetch
      specs = client.specifications
      loop do
        specs.links.specifications.each do |spec|
          fetch_spec spec
        end

        break unless specs.next?

        specs = specs.next
      end
      @index.sort!.save
      @index1.save
    end

    def fetch_spec(unrealized_spec)
      spec = realize unrealized_spec
      save_doc DataParser.parse(spec)

      if spec.links.respond_to?(:version_history) && spec.links.version_history
        version_history = realize spec.links.version_history
        version_history.links.spec_versions.each { |version| save_doc DataParser.parse(realize version) }
      end

      if spec.links.respond_to?(:predecessor_versions) && spec.links.predecessor_versions
        predecessor_versions = realize spec.links.predecessor_versions
        predecessor_versions.links.predecessor_versions.each { |version| save_doc DataParser.parse(realize version) }
      end

      if spec.links.respond_to?(:successor_versions) && spec.links.successor_versions
        successor_versions = realize spec.links.successor_versions
        successor_versions.links.successor_versions.each { |version| save_doc DataParser.parse(realize version) }
      end
    end

    #
    # Save document to file
    #
    # @param [RelatonW3c::W3cBibliographicItem, nil] bib bibliographic item
    #
    def save_doc(bib, warn_duplicate: true)
      return unless bib

      file = file_name(bib.docnumber)
      if @files.include?(file)
        Util.warn "File #{file} already exists. Document: #{bib.docnumber}" if warn_duplicate
      else
        pubid = PubId.parse bib.docnumber
        @index.add pubid, file
        @index1.add_or_update pubid.to_hash, file
        @files << file
      end
      File.write file, serialize(bib), encoding: "UTF-8"
    end

    def serialize(bib)
      case @format
      when "xml" then bib.to_xml(bibdata: true)
      when "yaml" then bib.to_hash.to_yaml
      else bib.send("to_#{@format}")
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

require "relaton/processor"

module RelatonW3c
  class Processor < Relaton::Processor
    attr_reader :idtype

    def initialize # rubocop:disable Lint/MissingSuper
      @short = :relaton_w3c
      @prefix = "W3C"
      @defaultprefix = %r{^W3C\s}
      @idtype = "W3C"
      @datasets = %w[w3c-rdf]
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonW3C::W3cBibliographicItem]
    def get(code, date, opts)
      ::RelatonW3c::W3cBibliography.get(code, date, opts)
    end

    #
    # Fetch all the documents from http://www.w3.org/2002/01/tr-automation/tr.rdf
    #
    # @param [String] _source source name
    # @param [Hash] opts
    # @option opts [String] :output directory to output documents
    # @option opts [String] :format
    #
    def fetch_data(_source, opts)
      DataFetcher.fetch(**opts)
    end

    # @param xml [String]
    # @return [RelatonCalconnect::CcBibliographicItem]
    def from_xml(xml)
      ::RelatonW3c::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonIsoBib::CcBibliographicItem]
    def hash_to_bib(hash)
      item_hash = ::RelatonW3c::HashConverter.hash_to_bib(hash)
      ::RelatonW3c::W3cBibliographicItem.new(**item_hash)
    end

    # Returns hash of XML grammar
    # @return [String]
    def grammar_hash
      @grammar_hash ||= ::RelatonW3c.grammar_hash
    end
  end
end

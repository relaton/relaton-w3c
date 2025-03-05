require "relaton/bib"
require "relaton/index"
require_relative "w3c/version"
require_relative "w3c/util"
# require "relaton_w3c/document_type"
# require "relaton_w3c/w3c_bibliography"
require_relative "w3c/item"
require_relative "w3c/bibitem"
require_relative "w3c/bibdata"
# require "relaton_w3c/xml_parser"
# require "relaton_w3c/bibxml_parser"
# require "relaton_w3c/hash_converter"
# require "relaton_w3c/pubid"
# require "relaton_w3c/data_fetcher"
# require "relaton_w3c/data_index"

module RelatonW3c
  class Error < StandardError; end

  # Returns hash of XML reammar
  # @return [String]
  def self.grammar_hash
    # gem_path = File.expand_path "..", __dir__
    # grammars_path = File.join gem_path, "grammars", "*"
    # grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
    Digest::MD5.hexdigest RelatonW3c::VERSION + RelatonBib::VERSION # grammars
  end
end

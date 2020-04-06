require "relaton_bib"
require "relaton_w3c/version"
require "relaton_w3c/w3c_bibliography"
require "relaton_w3c/w3c_bibliographic_item"
require "relaton_w3c/hit_collection"
require "relaton_w3c/hit"
require "relaton_w3c/scrapper"
require "relaton_w3c/xml_parser"
require "relaton_w3c/hash_converter"

module RelatonW3c
  class Error < StandardError; end

  # Returns hash of XML reammar
  # @return [String]
  def self.grammar_hash
    gem_path = File.expand_path "..", __dir__
    grammars_path = File.join gem_path, "grammars", "*"
    grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
    Digest::MD5.hexdigest grammars
  end
end

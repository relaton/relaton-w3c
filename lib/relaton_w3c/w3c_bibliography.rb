# frozen_string_literal: true

require "net/http"

module RelatonW3c
  # Class methods for search W3C standards.
  class W3cBibliography
    SOURCE = "https://raw.githubusercontent.com/relaton/relaton-data-w3c/main/"

    class << self
      # @param text [String]
      # @return [RelatonW3c::W3cBibliographicItem]
      def search(text) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        ref = DataParser.parse_identifier text.sub(/^W3C\s/, "")
        file = DataIndex.create_from_repo.search ref.gsub(" ", "-").squeeze("-")
        return unless file

        url = "#{SOURCE}#{file}"
        resp = Net::HTTP.get_response(URI.parse(url))
        return unless resp.code == "200"

        hash = YAML.safe_load resp.body
        item_hash = ::RelatonW3c::HashConverter.hash_to_bib(hash)
        ::RelatonW3c::W3cBibliographicItem.new(**item_hash)
      rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET,
             EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
             Net::ProtocolError, Errno::ETIMEDOUT
        raise RelatonBib::RequestError,
              "Could not access #{url}"
      end

      # @param ref [String] the W3C standard Code to look up
      # @param year [String, NilClass] not used
      # @param opts [Hash] options
      # @return [RelatonW3c::W3cBibliographicItem]
      def get(ref, _year = nil, _opts = {})
        warn "[relaton-w3c] (\"#{ref}\") fetching..."
        result = search(ref)
        unless result
          warn "[relaton-w3c] (\"#{ref}\") not found."
          return
        end

        found = result.docnumber
        warn "[relaton-w3c] (\"#{ref}\") found #{found}"
        result
      end
    end
  end
end

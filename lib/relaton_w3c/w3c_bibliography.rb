# frozen_string_literal: true

require "net/http"

module RelatonW3c
  # Class methods for search W3C standards.
  class W3cBibliography
    SOURCE = "https://raw.githubusercontent.com/relaton/relaton-data-w3c/main/data/"

    class << self
      # @param text [String]
      # @return [RelatonW3c::HitCollection]
      def search(text) # rubocop:disable Metrics/MethodLength
        # HitCollection.new text
        file = text.sub(/^W3C\s/, "").gsub(/[\s,:\/]/, "_").squeeze("_").upcase
        url = "#{SOURCE}#{file}.yaml"
        resp = Net::HTTP.get_response(URI.parse(url))
        hash = YAML.safe_load resp.body
        item_hash = ::RelatonW3c::HashConverter.hash_to_bib(hash)
        ::RelatonW3c::W3cBibliographicItem.new(**item_hash)
      rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET,
             EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
             Net::ProtocolError, Errno::ETIMEDOUT
        raise RelatonBib::RequestError,
              "Could not access #{HitCollection::DOMAIN}"
      end

      # @param ref [String] the W3C standard Code to look up
      # @param year [String, NilClass] not used
      # @param opts [Hash] options
      # @return [RelatonW3c::W3cBibliographicItem]
      def get(ref, _year = nil, _opts = {})
        warn "[relaton-w3c] (\"#{ref}\") fetching..."
        result = search(ref)
        return unless result # .any?

        # ret = result.first.fetch
        warn "[relaton-w3c] (\"#{ref}\") found #{result.title.first.title.content}"
        result
      end
    end
  end
end

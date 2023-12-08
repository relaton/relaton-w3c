# frozen_string_literal: true

require "net/http"

module RelatonW3c
  # Class methods for search W3C standards.
  class W3cBibliography
    SOURCE = "https://raw.githubusercontent.com/relaton/relaton-data-w3c/main/"
    INDEX = "index1"

    class << self
      # @param text [String]
      # @return [RelatonW3c::W3cBibliographicItem]
      def search(text) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        pubid = PubId.parse text.sub(/^W3C\s/, "")
        index = Relaton::Index.find_or_create(
          :W3C, url: "#{SOURCE}#{INDEX}.zip", file: "#{INDEX}.yaml", id_keys: PubId::PARTS
        )
        row = index.search { |r| pubid == r[:id] }.sort_by{ |r| r[:date].to_i }.first
        return unless row

        url = "#{SOURCE}#{row[:file]}"
        resp = Net::HTTP.get_response(URI.parse(url))
        return unless resp.code == "200"

        hash = YAML.safe_load resp.body
        hash["fetched"] = Date.today.to_s
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
        Util.warn "(#{ref}) Fetching from Relaton repository ..."
        result = search(ref)
        unless result
          Util.warn "(#{ref}) Not found."
          return
        end

        found = result.docidentifier.first.id
        Util.warn "(#{ref}) Found: `#{found}`"
        result
      end
    end
  end
end

# frozen_string_literal: true

module RelatonW3c
  # Class methods for search W3C standards.
  class W3cBibliography
    class << self
      # @param text [String]
      # @return [RelatonW3c::HitCollection]
      def search(text)
        HitCollection.new text
      rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError,
             OpenSSL::SSL::SSLError, Errno::ETIMEDOUT
        raise RelatonBib::RequestError, "Could not access #{HitCollection::DOMAIN}"
      end

      # @param ref [String] the W3C standard Code to look up
      # @param year [String, NilClass] not used
      # @param opts [Hash] options
      # @return [RelatonW3c::W3cBibliographicItem]
      def get(ref, _year = nil, opts = {})
        warn "[relaton-w3c] (\"#{ref}\") fetching..."
        result = search(ref)
        return unless result.any?

        ret = result.first.fetch
        warn "[relaton-w3c] (\"#{ref}\") found #{ret.title.first.title.content}"
        ret
      end
    end
  end
end

require "concurrent/map"

module Relaton
  module W3c
    # Thin wrapper over lutaml-hal's `realize`. Successful objects are cached by
    # w3c_api (it caches realized objects keyed by URL), so this only remembers
    # resources that failed terminally and returns nil for them — so one broken
    # link doesn't abort the crawl and isn't re-fetched on every reference.
    #
    # Transient failures are retried upstream: w3c_api retries HTTP 403 (the
    # W3C rate-limit signal) and connection/timeout errors, and lutaml-hal
    # retries 429 and 5xx. By the time an error surfaces here it is terminal.
    module SafeRealize
      # Hrefs that failed terminally — one map shared by every includer
      # (DataFetcher and DataParser) since a broken resource is broken for the
      # whole crawl. Initialized eagerly (at load, single-threaded) so the
      # parallel fetcher's first concurrent access can't race a lazy `||=`;
      # Concurrent::Map then handles the concurrent reads/writes.
      @skipped = Concurrent::Map.new

      def self.skipped
        @skipped
      end

      # @param parent_resource [Object, nil] the index/page the link came from.
      #   When the page was fetched with `embed: true`, its inlined `_embedded`
      #   payload lets the link realize from memory instead of issuing an HTTP
      #   request. nil (the default) preserves the plain remote-fetch behavior.
      def realize(obj, parent_resource: nil)
        href = resolve_href(obj)
        return nil if SafeRealize.skipped.key?(href)

        obj.realize(parent_resource: parent_resource)
      rescue Lutaml::Hal::ConnectionError, Lutaml::Hal::TimeoutError, Faraday::Error, Net::OpenTimeout => e
        # Network-level failure (already retried by w3c_api). The resource itself
        # is fine, so don't skip it permanently — a later reference can try again.
        Util.warn "Failed to realize object: #{href}, error: #{e.message}"
        nil
      rescue Lutaml::Hal::NotFoundError
        Util.warn "Object not found: #{href}"
        SafeRealize.skipped[href] = true
        nil
      rescue Lutaml::Hal::Error => e
        # Definitive upstream error (403 rate-limit, 5xx, 429) already retried by
        # w3c_api / lutaml-hal. Skip the broken/unavailable resource rather than
        # re-hitting it for every link that references it.
        Util.warn "Skipping #{href}, upstream error after retries: #{e.message}"
        SafeRealize.skipped[href] = true
        nil
      end

      private

      def resolve_href(obj)
        obj.href || obj.links.self.href
      end
    end
  end
end

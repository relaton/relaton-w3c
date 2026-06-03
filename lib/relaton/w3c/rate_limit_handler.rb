require "concurrent/map"

module Relaton
  module W3c
    # Memoizes realized objects so a document linked from many places is only
    # fetched once, and skips resources that fail terminally so one bad link
    # does not abort the whole crawl.
    #
    # Transient failures are retried upstream: w3c_api retries HTTP 403 (the
    # W3C rate-limit signal) and connection/timeout errors, and lutaml-hal
    # retries 429 and 5xx. By the time an error surfaces here it is terminal.
    module RateLimitHandler
      # Concurrent::Map so multiple fetcher threads can hit the cache without
      # a global lock. Duplicate concurrent fetches of the same URL are
      # possible but harmless; the second write just replaces the first.
      def self.fetched_objects
        @fetched_objects ||= Concurrent::Map.new
      end

      def realize(obj)
        href = resolve_href(obj)
        return RateLimitHandler.fetched_objects[href] if RateLimitHandler.fetched_objects.key?(href)

        RateLimitHandler.fetched_objects[href] = obj.realize
      rescue Lutaml::Hal::ConnectionError, Lutaml::Hal::TimeoutError, Faraday::Error, Net::OpenTimeout => e
        # Network-level failure (already retried by w3c_api). The resource itself
        # is fine, so do not cache — a later reference can try again.
        Util.warn "Failed to realize object: #{href}, error: #{e.message}"
      rescue Lutaml::Hal::NotFoundError
        Util.warn "Object not found: #{href}"
        RateLimitHandler.fetched_objects[href] = nil
      rescue Lutaml::Hal::Error => e
        # Definitive upstream error (403 rate-limit, 5xx, 429) already retried by
        # w3c_api / lutaml-hal. Cache nil to skip the broken/unavailable resource
        # rather than re-hitting it for every link that references it.
        Util.warn "Skipping #{href}, upstream error after retries: #{e.message}"
        RateLimitHandler.fetched_objects[href] = nil
      end

      private

      def resolve_href(obj)
        obj.href || obj.links.self.href
      end
    end
  end
end

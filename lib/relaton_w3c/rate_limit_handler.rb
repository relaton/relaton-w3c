module RelatonW3c
  module RateLimitHandler
    def self.fetched_objects
      @fetched_objects ||= {}
    end

    def realize(obj)
      href = obj.href || obj.links.self.href
      return RateLimitHandler.fetched_objects[href] if RateLimitHandler.fetched_objects.key?(href)

      n = 1
      begin
        RateLimitHandler.fetched_objects[href] = obj.realize
      rescue NameError, # NameError caused by lutaml-hal-0.1.7/lib/lutaml/hal/client.rb:51:in `rescue in get': uninitialized constant Lutaml::Hal::Client::ConnectionError
          Faraday::ConnectionFailed, Net::OpenTimeout => e
        if n < 5
          sleep_time = n * n
          n += 1
          Util.warn "Rate limit exceeded for #{href}, retrying in #{sleep_time} seconds..."
          sleep sleep_time
          retry
        else
          Util.warn "Failed to realize object: #{href}"
          raise e
        end
      rescue Lutaml::Hal::NotFoundError
        Util.warn "Object not found: #{href}"
        RateLimitHandler.fetched_objects[href] = nil
      end
    end
  end
end

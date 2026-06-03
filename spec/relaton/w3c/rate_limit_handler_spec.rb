require "spec_helper"
require_relative "../../../lib/relaton/w3c/data_fetcher"

RSpec.describe Relaton::W3c::RateLimitHandler do
  let(:dummy_class) do
    Class.new do
      include Relaton::W3c::RateLimitHandler
    end
  end

  subject(:handler) { dummy_class.new }

  before { Relaton::W3c::RateLimitHandler.fetched_objects.clear }

  describe "#resolve_href" do
    it "returns obj.href when present" do
      obj = double(href: "https://example.com/spec")
      expect(handler.send(:resolve_href, obj)).to eq "https://example.com/spec"
    end

    it "falls back to obj.links.self.href" do
      link_self = double(href: "https://example.com/fallback")
      links = double(self: link_self)
      obj = double(href: nil, links: links)
      expect(handler.send(:resolve_href, obj)).to eq "https://example.com/fallback"
    end
  end

  describe "#realize" do
    let(:href) { "https://example.com/spec" }
    let(:realized) { double("realized_object") }
    let(:obj) { double(href: href) }

    context "when the object is already cached" do
      before { Relaton::W3c::RateLimitHandler.fetched_objects[href] = realized }

      it "returns the cached value without calling obj.realize" do
        expect(obj).not_to receive(:realize)
        expect(handler.realize(obj)).to eq realized
      end
    end

    context "when obj.realize succeeds" do
      before { allow(obj).to receive(:realize).and_return(realized) }

      it "caches and returns the realized object" do
        result = handler.realize(obj)
        expect(result).to eq realized
        expect(Relaton::W3c::RateLimitHandler.fetched_objects[href]).to eq realized
      end
    end

    # Retries now live upstream (w3c_api retries 403 + connection/timeout,
    # lutaml-hal retries 429 + 5xx), so the handler never retries.
    context "when a network error reaches the handler" do
      before { allow(Relaton.logger_pool).to receive(:warn) }

      it "does not retry and does not cache, so a later reference can try again" do
        call_count = 0
        allow(obj).to receive(:realize) do
          call_count += 1
          raise Faraday::ConnectionFailed, "connection failed"
        end

        result = handler.realize(obj)
        expect(result).to be_nil
        expect(call_count).to eq 1
        expect(Relaton::W3c::RateLimitHandler.fetched_objects.key?(href)).to be false
        expect(Relaton.logger_pool).to have_received(:warn).with(/Failed to realize object/, anything)
      end
    end

    context "when Lutaml::Hal::NotFoundError is raised" do
      before do
        allow(obj).to receive(:realize).and_raise(Lutaml::Hal::NotFoundError)
        allow(Relaton.logger_pool).to receive(:warn)
      end

      it "warns, caches nil, and returns nil" do
        result = handler.realize(obj)
        expect(result).to be_nil
        expect(Relaton::W3c::RateLimitHandler.fetched_objects[href]).to be_nil
        expect(Relaton::W3c::RateLimitHandler.fetched_objects.key?(href)).to be true
        expect(Relaton.logger_pool).to have_received(:warn).with(/Object not found/, anything)
      end
    end

    context "when a definitive upstream error reaches the handler" do
      before { allow(Relaton.logger_pool).to receive(:warn) }

      it "caches nil for a persistent 403 (W3C rate-limit) without retrying" do
        call_count = 0
        allow(obj).to receive(:realize) do
          call_count += 1
          raise Lutaml::Hal::Error, "Status: 403"
        end

        result = handler.realize(obj)
        expect(result).to be_nil
        expect(call_count).to eq 1
        expect(Relaton::W3c::RateLimitHandler.fetched_objects[href]).to be_nil
        expect(Relaton::W3c::RateLimitHandler.fetched_objects.key?(href)).to be true
        expect(Relaton.logger_pool).to have_received(:warn).with(/Skipping .* upstream error/, anything)
      end

      it "caches nil for a 5xx without retrying" do
        call_count = 0
        allow(obj).to receive(:realize) do
          call_count += 1
          raise Lutaml::Hal::ServerError, "500"
        end

        result = handler.realize(obj)
        expect(result).to be_nil
        expect(call_count).to eq 1
        expect(Relaton::W3c::RateLimitHandler.fetched_objects.key?(href)).to be true
      end

      it "caches nil for a 429 without retrying" do
        allow(obj).to receive(:realize).and_raise(Lutaml::Hal::TooManyRequestsError, "429")

        result = handler.realize(obj)
        expect(result).to be_nil
        expect(Relaton::W3c::RateLimitHandler.fetched_objects.key?(href)).to be true
      end
    end
  end
end

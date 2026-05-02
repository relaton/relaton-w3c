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

    context "when a retryable error occurs" do
      before do
        allow(handler).to receive(:sleep)
        allow(Relaton.logger_pool).to receive(:warn)
      end

      it "retries and succeeds" do
        call_count = 0
        allow(obj).to receive(:realize) do
          call_count += 1
          raise Faraday::ConnectionFailed, "connection failed" if call_count < 3
          realized
        end

        result = handler.realize(obj)
        expect(result).to eq realized
        expect(call_count).to eq 3
      end

      it "uses exponential backoff sleep times" do
        allow(obj).to receive(:realize) do
          raise Faraday::ConnectionFailed, "connection failed"
        end

        handler.realize(obj)

        expect(handler).to have_received(:sleep).with(1).ordered
        expect(handler).to have_received(:sleep).with(4).ordered
        expect(handler).to have_received(:sleep).with(9).ordered
        expect(handler).to have_received(:sleep).with(16).ordered
      end

      it "gives up after MAX_RETRIES and does not cache" do
        allow(obj).to receive(:realize).and_raise(Faraday::ConnectionFailed, "fail")

        result = handler.realize(obj)
        expect(result).to be_nil
        expect(Relaton::W3c::RateLimitHandler.fetched_objects).not_to have_key(href)
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
        expect(Relaton::W3c::RateLimitHandler.fetched_objects).to have_key(href)
        expect(Relaton.logger_pool).to have_received(:warn).with(/Object not found/, anything)
      end
    end

    context "when Lutaml::Hal::ServerError is raised" do
      before do
        allow(handler).to receive(:sleep)
        allow(Relaton.logger_pool).to receive(:warn)
      end

      it "retries and succeeds on transient 5xx" do
        call_count = 0
        allow(obj).to receive(:realize) do
          call_count += 1
          raise Lutaml::Hal::ServerError, "500" if call_count < 3
          realized
        end

        result = handler.realize(obj)
        expect(result).to eq realized
        expect(call_count).to eq 3
      end

      it "gives up after MAX_RETRIES and caches nil on persistent 5xx" do
        allow(obj).to receive(:realize).and_raise(Lutaml::Hal::ServerError, "500")

        result = handler.realize(obj)
        expect(result).to be_nil
        expect(Relaton::W3c::RateLimitHandler.fetched_objects[href]).to be_nil
        expect(Relaton::W3c::RateLimitHandler.fetched_objects).to have_key(href)
        expect(Relaton.logger_pool).to have_received(:warn).with(/Server error for .* skipping/, anything)
      end
    end
  end
end

require "relaton/core"
require "w3c_api"
require_relative "../w3c"
require_relative "safe_realize"
require_relative "data_parser"
require_relative "pubid"

module Relaton
  module W3c
    class DataFetcher < Core::DataFetcher
      include Relaton::W3c::SafeRealize

      DEFAULT_CONCURRENCY = 8

      # Number of fetch_spec worker threads. Tunable via env var so CI or
      # local runs can dial it down (e.g. for debugging or to lighten load
      # on api.w3.org).
      def self.concurrency
        (ENV["RELATON_W3C_FETCH_CONCURRENCY"] || DEFAULT_CONCURRENCY).to_i
      end

      def initialize(*args)
        super
        @mutex = Mutex.new
      end

      def index
        @index ||= Relaton::Index.find_or_create(:W3C, file: "#{INDEXFILE}.yaml")
      end

      def log_error(msg)
        Util.error msg
      end

      def client
        @client ||= W3cApi::Client.new
      end

      #
      # Parse documents in parallel. The crawler is heavily I/O-bound on
      # api.w3.org round-trips (~30-50k requests per run), so a small thread
      # pool gives a near-linear speedup. Pagination still happens serially
      # because each page depends on the previous response's `next` link.
      #
      def fetch(_source = nil)
        n_workers = self.class.concurrency
        queue = SizedQueue.new(n_workers * 4)
        workers = Array.new(n_workers) { spawn_worker(queue) }

        specs = client.specifications
        loop do
          specs.links.specifications.each { |spec| queue << spec }
          break unless specs.next?

          # Route pagination through realize so transient 403/5xx on the
          # next-page link retry with backoff instead of crashing the crawl.
          next_page = realize(specs.links.next)
          break unless next_page

          specs = next_page
        end

        n_workers.times { queue << nil } # poison pills
        workers.each(&:join)

        index.save
        report_errors
      end

      def fetch_spec(unrealized_spec)
        spec = realize unrealized_spec
        return unless spec

        local_errors = Hash.new(true)
        save_doc DataParser.parse(spec, local_errors)

        if spec.links.respond_to?(:version_history) && spec.links.version_history
          version_history = realize spec.links.version_history
          version_history&.links&.spec_versions&.each { |version| parse_and_save version }
        end

        if spec.links.respond_to?(:predecessor_versions) && spec.links.predecessor_versions
          predecessor_versions = realize spec.links.predecessor_versions
          predecessor_versions&.links&.predecessor_versions&.each { |version| parse_and_save version }
        end

        if spec.links.respond_to?(:successor_versions) && spec.links.successor_versions
          successor_versions = realize spec.links.successor_versions
          successor_versions&.links&.successor_versions&.each { |version| parse_and_save version }
        end

        @mutex.synchronize { local_errors.each { |k, v| @errors[k] &&= v } }
      end

      #
      # Save document to file
      #
      # @param [Relaton::W3c::ItemData, nil] bib bibliographic item
      #
      def save_doc(bib, warn_duplicate: true)
        return unless bib

        file = file_name(bib.docnumber)
        @mutex.synchronize do
          if @files.include?(file)
            Util.warn "File #{file} already exists. Document: #{bib.docnumber}" if warn_duplicate
          else
            pubid = PubId.parse bib.docnumber
            index.add_or_update pubid.to_hash, file
            @files << file
          end
          File.write file, serialize(bib), encoding: "UTF-8"
        end
      end

      def to_xml(bib)
        bib.to_xml(bibdata: true)
      end

      def to_yaml(bib)
        bib.to_yaml
      end

      def to_bibxml(bib)
        bib.to_xml
      end

      #
      # Generate file name
      #
      # @param [String] id document id
      #
      # @return [String] file name
      #
      def file_name(id)
        name = id.sub(/^W3C\s/, "").gsub(/[\s,:\/+]/, "_").squeeze("_").downcase
        File.join @output, "#{name}.#{@ext}"
      end

      private

      def spawn_worker(queue)
        Thread.new do
          while (spec = queue.pop)
            begin
              fetch_spec spec
            rescue StandardError => e
              log_error "fetch_spec failed: #{e.class}: #{e.message}\n" \
                        "#{e.backtrace.first(5).join("\n")}"
            end
          end
        end
      end

      def parse_and_save(version)
        realized = realize version
        save_doc DataParser.parse(realized) if realized
      end
    end
  end
end

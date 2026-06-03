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

      # Whether to crawl each specification's version history (version_history,
      # predecessor_versions, successor_versions). Enabled by default for a
      # complete dataset. Set RELATON_W3C_FETCH_VERSIONS=false for a faster,
      # shallower crawl that emits only the top-level specifications and skips
      # the per-spec version fan-out (the bulk of the API requests).
      def self.fetch_versions?
        val = ENV["RELATON_W3C_FETCH_VERSIONS"]
        return true if val.nil? || val.empty?

        !%w[0 false no off].include?(val.strip.downcase)
      end

      def initialize(*args)
        super
        @mutex = Mutex.new
        @interrupted = false
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
      # pool gives a near-linear speedup. Pagination still happens serially:
      # each page's `next?` flag gates whether the next page is requested.
      #
      # A SIGINT (Ctrl-C) is handled gracefully: the producer stops queuing and
      # the workers stop processing after their in-flight spec, then the index
      # of everything fetched so far is saved rather than the run being lost.
      #
      def fetch(_source = nil)
        n_workers = self.class.concurrency
        queue = SizedQueue.new(n_workers * 4)
        workers = Array.new(n_workers) { spawn_worker(queue) }

        with_interrupt_handler do
          enqueue_specs(queue)
          n_workers.times { queue << nil } # poison pills
          workers.each(&:join)
          Util.warn "Crawl interrupted — saving progress collected so far." if @interrupted
          index.save
        end

        report_errors
      end

      #
      # Page through the specifications index, feeding each spec (paired with
      # its embedded page) to the worker queue. Returns early when interrupted.
      #
      # embed: true inlines each specification's full payload into the index
      # page's `_embedded` block, so a spec link realizes from that page in
      # memory instead of making its own HTTP request — one request per page
      # rather than one per specification. The page is queued alongside each
      # link so the worker can hand it back to realize as the parent_resource.
      #
      def enqueue_specs(queue)
        specs = client.specifications(embed: true)
        loop do
          page = specs
          page.links.specifications.each do |spec|
            break if @interrupted

            queue << [spec, page]
          end
          break if @interrupted || !page.next?

          # Fetch the next page through the client's fetch path rather than
          # realizing the `next` link: only fetch populates the page's
          # embedded_data, so this keeps embed working past page 1. Realizing
          # the `next` link drops `_embedded` and forces a per-spec HTTP
          # request for every specification on every later page.
          next_page = fetch_specifications_page(page.page + 1)
          break unless next_page

          specs = next_page
        end
      end

      def fetch_spec(unrealized_spec, page = nil)
        # When `page` came from an embed:true fetch, realizing against it as the
        # parent_resource serves the spec from embedded data (no HTTP request).
        spec = realize(unrealized_spec, parent_resource: page)
        return unless spec

        local_errors = Hash.new(true)
        save_doc DataParser.parse(spec, local_errors)

        fetch_versions(spec) if self.class.fetch_versions?

        @mutex.synchronize { local_errors.each { |k, v| @errors[k] &&= v } }
      end

      #
      # Crawl a specification's version history: its dated editions plus the
      # predecessor/successor version chains. Each entry is a separate HTTP
      # request, so this is the bulk of a run and can be skipped via
      # RELATON_W3C_FETCH_VERSIONS=false (see .fetch_versions?).
      #
      def fetch_versions(spec)
        if spec.links.respond_to?(:version_history) && spec.links.version_history
          version_history = realize spec.links.version_history
          version_history&.links&.spec_versions&.each { |version| parse_and_save version }
        end

        if spec.links.respond_to?(:predecessor_versions) && spec.links.predecessor_versions
          predecessor_versions = realize spec.links.predecessor_versions
          predecessor_versions&.links&.predecessor_versions&.each { |version| parse_and_save version }
        end

        return unless spec.links.respond_to?(:successor_versions) && spec.links.successor_versions

        successor_versions = realize spec.links.successor_versions
        successor_versions&.links&.successor_versions&.each { |version| parse_and_save version }
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

      # Install a SIGINT handler for the duration of the crawl so Ctrl-C sets
      # the @interrupted flag (observed by the producer loop and the workers)
      # instead of killing the process mid-write. The trap body is kept minimal
      # (no I/O or locking) because trap context is restricted; the user-facing
      # notice is printed from the main thread once the crawl winds down. The
      # previous handler is restored on the way out so the trap doesn't leak
      # into the host process.
      def with_interrupt_handler
        previous = Signal.trap("INT") { @interrupted = true }
        yield
      ensure
        Signal.trap("INT", previous || "DEFAULT")
      end

      # Fetch one page of the specifications index with embed enabled. Goes
      # through the client (the register's fetch path) so the page's
      # embedded_data is populated. Transient 403/5xx/connection failures are
      # already retried upstream (w3c_api/lutaml-hal); a terminal error here
      # stops pagination gracefully rather than crashing the crawl.
      def fetch_specifications_page(number)
        client.specifications(embed: true, page: number)
      rescue Lutaml::Hal::Error, Faraday::Error => e
        log_error "Failed to fetch specifications page #{number}: " \
                  "#{e.class}: #{e.message}"
        nil
      end

      def spawn_worker(queue)
        Thread.new do
          while (item = queue.pop)
            # Once interrupted, drain the queue without processing so the
            # producer unblocks and the pool reaches its poison pills quickly.
            next if @interrupted

            spec, page = item
            begin
              fetch_spec spec, page
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

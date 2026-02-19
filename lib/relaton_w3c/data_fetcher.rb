require "w3c_api"
require_relative "data_parser"

module RelatonW3c
  class DataFetcher

    #
    # Data fetcher initializer
    #
    # @param [String] output directory to save files
    # @param [String] format format of output files (xml, yaml, bibxml)
    # @param [Boolean] fetch_versions whether to fetch version history (slower but more complete)
    #
    def initialize(output, format, fetch_versions: true)
      @output = output
      @format = format
      @ext = format.sub(/^bib/, "")
      @files = Set.new
      @fetched_urls = {}
      @index = DataIndex.create_from_file
      @index1 = Relaton::Index.find_or_create :W3C, file: "index1.yaml"
      @fetch_versions = fetch_versions
    end

    #
    # Initialize fetcher and run fetch
    #
    # @param [String] output directory to save files, default: "data"
    # @param [String] format format of output files (xml, yaml, bibxml), default: yaml
    # @param [Boolean] fetch_versions whether to fetch version history (slower but more complete), default: true
    #
    def self.fetch(output: "data", format: "yaml", fetch_versions: true)
      t1 = Time.now
      puts "Started at: #{t1}"
      puts "Fetch versions: #{fetch_versions ? 'enabled (slower, more complete)' : 'disabled (faster)'}"
      FileUtils.mkdir_p output
      new(output, format, fetch_versions: fetch_versions).fetch
      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    end

    def client
      @client ||= W3cApi::Client.new
    end

    #
    # Parse documents
    #
    def fetch
      @processed_count = 0
      @page_count = 0

      # Set up signal handler for graceful interruption
      interrupted = false
      Signal.trap("INT") do
        puts "\n\nReceived interrupt signal. Finishing current page and saving progress..."
        interrupted = true
      end

      # Fetch specifications with embed: true to get embedded related data
      specs = client.specifications(embed: true)
      loop do
        @page_count += 1
        page_start_time = Time.now
        page_processed = 0

        puts "Processing page #{@page_count} (#{specs.links.specifications.size} specifications)..."

        specs.links.specifications.each_with_index do |spec, index|
          if interrupted
            puts "Interrupted during page #{@page_count}, spec #{index + 1}/#{specs.links.specifications.size}"
            break
          end

          begin
            # Use embedded data when available to avoid HTTP requests
            fetch_spec spec, specs
            @processed_count += 1
            page_processed += 1

            # Show progress every 10 specs or at the end of page
            if (page_processed % 10 == 0) || (index == specs.links.specifications.size - 1)
              elapsed = Time.now - page_start_time
              rate = page_processed / elapsed
              puts "  Processed #{page_processed}/#{specs.links.specifications.size} specs on page #{@page_count} (#{rate.round(2)} specs/sec, total: #{@processed_count})"
            end
          rescue => e
            puts "  [ERROR] Failed to process spec #{index + 1}/#{specs.links.specifications.size}: #{spec.href || 'embedded'}"
            puts "  [ERROR] Exception: #{e.class}: #{e.message}"
            puts "  [ERROR] Backtrace: #{e.backtrace.first(3).join(', ')}"
            puts "  [ERROR] Continuing with next spec..."
            # Continue processing other specs
          end
        end

        page_elapsed = Time.now - page_start_time
        puts "Completed page #{@page_count} in #{page_elapsed.round(2)} seconds (#{page_processed} specs)"

        # Check for next page
        has_next = specs.next?
        puts "Checking for next page... has_next: #{has_next}"

        break if interrupted || !has_next

        puts "Fetching next page..."
        specs = specs.next
        puts "Successfully fetched next page"
      end

      puts "\nSaving indexes..."
      @index.sort!.save
      @index1.save
      puts "Indexes saved. Total specifications processed: #{@processed_count}"

      if interrupted
        puts "Crawling was interrupted but progress has been saved."
      else
        puts "Crawling completed successfully!"
      end
    end

    def fetch_spec(unrealized_spec, parent_resource = nil)
      # Use embedded data when available to avoid HTTP requests
      puts "  [DEBUG] Processing spec: #{unrealized_spec.href || 'embedded'}"

      if parent_resource
        puts "    [EMBED] Using embedded data (no HTTP request)"
        spec = unrealized_spec.realize(parent_resource: parent_resource)
      else
        puts "    [HTTP] Making HTTP request to realize spec"
        spec = realize(unrealized_spec)
      end

      return unless spec

      save_doc DataParser.parse(spec)

      if @fetch_versions
        version_count = 0

        # Fetch version history if available
        if spec.links.respond_to?(:version_history) && spec.links.version_history
          puts "    [VERSIONS] Fetching version history..."
          version_history = realize spec.links.version_history
          if version_history&.links&.spec_versions
            version_history.links.spec_versions.each do |version|
              puts "      [VERSION] Processing version: #{version.href || 'embedded'}"
              realized_version = realize version
              if realized_version
                save_doc DataParser.parse(realized_version)
                version_count += 1
                puts "      [VERSION] ✓ Saved version #{version_count}"
              end
            end
          end
        end

        # Fetch predecessor versions if available
        if spec.links.respond_to?(:predecessor_versions) && spec.links.predecessor_versions
          puts "    [VERSIONS] Fetching predecessor versions..."
          predecessor_versions = realize spec.links.predecessor_versions
          if predecessor_versions&.links&.predecessor_versions
            predecessor_versions.links.predecessor_versions.each do |version|
              puts "      [VERSION] Processing predecessor: #{version.href || 'embedded'}"
              realized_version = realize version
              if realized_version
                save_doc DataParser.parse(realized_version)
                version_count += 1
                puts "      [VERSION] ✓ Saved predecessor version #{version_count}"
              end
            end
          end
        end

        # Fetch successor versions if available
        if spec.links.respond_to?(:successor_versions) && spec.links.successor_versions
          puts "    [VERSIONS] Fetching successor versions..."
          successor_versions = realize spec.links.successor_versions
          if successor_versions&.links&.successor_versions
            successor_versions.links.successor_versions.each do |version|
              puts "      [VERSION] Processing successor: #{version.href || 'embedded'}"
              realized_version = realize version
              if realized_version
                save_doc DataParser.parse(realized_version)
                version_count += 1
                puts "      [VERSION] ✓ Saved successor version #{version_count}"
              end
            end
          end
        end

        if version_count > 0
          puts "    [VERSIONS] Total versions retrieved for this spec: #{version_count}"
        else
          puts "    [VERSIONS] No versions found for this spec"
        end
      end
    end

    #
    # Save document to file
    #
    # @param [RelatonW3c::W3cBibliographicItem, nil] bib bibliographic item
    #
    def save_doc(bib, warn_duplicate: true)
      return unless bib

      file = file_name(bib.docnumber)
      if @files.include?(file)
        Util.warn "File #{file} already exists. Document: #{bib.docnumber}" if warn_duplicate
      else
        pubid = PubId.parse bib.docnumber
        @index.add pubid, file
        @index1.add_or_update pubid.to_hash, file
        @files << file
      end
      File.write file, serialize(bib), encoding: "UTF-8"
    end

    def serialize(bib)
      case @format
      when "xml" then bib.to_xml(bibdata: true)
      when "yaml" then bib.to_hash.to_yaml
      else bib.send("to_#{@format}")
      end
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

    #
    # Realize a HAL link using w3c_api's built-in rate limiting
    #
    # @param [Object] obj HAL link object to realize
    # @return [Object] realized object
    #
    def realize(obj)
      # Use the built-in realize method which includes sophisticated rate limiting
      # with exponential backoff and Retry-After header support
      obj.realize
    rescue Lutaml::Hal::NotFoundError
      Util.warn "Object not found: #{obj.href || obj.links.self.href}"
      nil
    end
  end
end

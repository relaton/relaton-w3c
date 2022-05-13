require "zip"

module RelatonW3c
  class DataIndex
    #
    # Initialize data index.
    #
    # @param [String] index_file path to index file
    # @param [Array<Hash>] index index data
    #
    def initialize(index_file: "index-w3c.yaml", index: [])
      @index_file = index_file
      @index = index
    end

    #
    # Add document to index
    #
    # @param [String] docnumber document number
    # @param [String] file path to document file
    #
    def add(docnumber, file)
      dnparts = self.class.docnumber_to_parts docnumber
      dnparts[:file] = file
      @index << dnparts
    end

    #
    # Save index to file.
    #
    def save
      File.write @index_file, @index.to_yaml, encoding: "UTF-8"
    end

    #
    # Sort index
    #
    # @return [Array<Hash>] sorted index
    #
    def sort!
      @index.sort! { |a, b| compare_index_items a, b }
      self
    end

    #
    # Search filename in index
    #
    # @param [String] ref reference
    #
    # @return [String] document's filename
    #
    def search(ref) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      dparts = self.class.docnumber_to_parts(ref)
      return if dparts[:code].nil?

      @index.detect do |parts|
        parts[:code].match?(/^#{Regexp.escape dparts[:code]}/i) &&
          (dparts[:stage].nil? || dparts[:stage].casecmp?(parts[:stage])) &&
          (dparts[:type].nil? || dparts[:type].casecmp?(parts[:type]) ||
            (parts[:type].nil? && dparts[:type] == "TR")) &&
          (dparts[:date].nil? || dparts[:date] == parts[:date]) &&
          (dparts[:suff].nil? || dparts[:suff].casecmp?(parts[:suff]))
      end&.fetch(:file)
    end

    #
    # Compare index items
    #
    # @param [Hash] aid first item
    # @param [Hash] bid second item
    #
    # @return [Integer] comparison result
    #
    def compare_index_items(aid, bid) # rubocop:disable Metrics/AbcSize
      ret = aid[:code].downcase <=> bid[:code].downcase
      ret = stage_weight(bid[:stage]) <=> stage_weight(aid[:stage]) if ret.zero?
      ret = date_weight(bid[:date]) <=> date_weight(aid[:date]) if ret.zero?
      # ret = aid[:type] <=> bid[:type] if ret.zero?
      ret
    end

    #
    # Weight of stage
    #
    # @param [String, nil] stage stage
    #
    # @return [Integer] weight
    #
    def stage_weight(stage)
      return DataParser::STAGES.size if stage.nil?

      DataParser::STAGES.keys.index(stage)
    end

    #
    # Weight of date
    #
    # @param [String] date date
    #
    # @return [String] weight
    #
    def date_weight(date)
      return "99999999" if date.nil?

      date
    end

    class << self
      #
      # Create index from a GitHub repository
      #
      # @return [RelatonW3c::DataIndex] data index
      #
      def create_from_repo # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        resp = Zip::InputStream.new URI("#{W3cBibliography::SOURCE}index-w3c.zip").open
        zip = resp.get_next_entry

        # Newer versions of Psych uses the `permitted_classes:` parameter
        index = if YAML.method(:safe_load).parameters.collect(&:last).index(:permitted_classes)
                  YAML.safe_load(zip.get_input_stream.read, permitted_classes: [Symbol])
                else
                  YAML.safe_load(zip.get_input_stream.read, [Symbol])
                end

        DataIndex.new index: index
      end

      #
      # Parse document number to parts
      #
      # @param [String] docnumber document number
      #
      # @return [Hash{Symbol=>String}] document parts
      #
      def docnumber_to_parts(docnumber) # rubocop:disable Metrics/MethodLength
        %r{
          ^(?:(?:(?<stage>WD|CRD|CR|PR|PER|REC|SPSD|OBSL|RET)|(?<type>D?NOTE|TR))-)?
          (?<code>\w+(?:[+-][\w.]+)*?)
          (?:-(?<date>\d{8}|\d{6}|\d{4}))?
          (?:/(?<suff>\w+))?$
        }xi =~ docnumber
        entry = { code: code }
        entry[:stage] = stage if stage
        entry[:type] = type if type
        entry[:date] = date if date
        entry[:suff] = suff if suff
        entry
      end
    end
  end
end

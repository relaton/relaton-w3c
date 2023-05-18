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
    # Add document to index or update it if already exists
    #
    # @param [RelatonW3c::PubId] pubid document number
    # @param [String] file path to document file
    #
    def add(pubid, file) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
      # dnparts = self.class.docnumber_to_parts docnumber
      # pubid = PubId.parse docnumber
      rec = @index.detect { |i| i[:file] == file }
      if rec
        rec[:code] = pubid.code
        pubid.stage ? rec[:stage] = pubid.stage : rec.delete(:stage)
        pubid.type ? rec[:type] = pubid.type : rec.delete(:type)
        pubid.date ? rec[:date] = pubid.date : rec.delete(:date)
        pubid.suff ? rec[:suff] = pubid.suff : rec.delete(:suff)
      else
        dnparts = pubid.to_hash
        dnparts[:file] = file
        @index << dnparts
      end
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
      pubid = PubId.parse(ref)
      return if pubid.code.nil?

      @index.detect do |parts|
        parts[:code].match?(/^#{Regexp.escape pubid.code}/i) &&
          (pubid.stage.nil? || pubid.stage.casecmp?(parts[:stage])) &&
          (pubid.type.nil? || pubid.type.casecmp?(parts[:type]) ||
            (parts[:type].nil? && pubid.type == "TR")) &&
          (pubid.date.nil? || pubid.date == parts[:date]) &&
          (pubid.suff.nil? || pubid.suff.casecmp?(parts[:suff]))
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
      def create_from_repo
        uri = URI("#{W3cBibliography::SOURCE}index-w3c.zip").open
        resp = Zip::InputStream.new uri
        zip = resp.get_next_entry
        index = RelatonBib.parse_yaml(zip.get_input_stream.read, [Symbol])
        new index: index
      end

      #
      # Create index from a file
      #
      # @param [String] index_file path to index file
      #
      # @return [RelatonW3c::DataIndex] data index
      #
      def create_from_file(index_file = "index-w3c.yaml")
        index = if File.exist?(index_file)
                  RelatonBib.parse_yaml(File.read(index_file), [Symbol])
                else []
                end
        new index_file: index_file, index: index
      end
    end
  end
end

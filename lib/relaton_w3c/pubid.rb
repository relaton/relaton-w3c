module RelatonW3c
  class PubId
    PARTS = %i[code stage type date suff].freeze

    PARTS.each { |part| attr_accessor part }

    def initialize(**parts)
      PARTS.each { |part| send "#{part}=", parts[part] }
    end

    #
    # Parse document identifier.
    #
    # @param [String] docnumber document identifier
    #
    # @return [RelatonW3c::PubId] document identifier parts
    #
    def self.parse(docnumber) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      %r{
        (?:^|/)(?:(?:(?<stage>WD|CRD|CR|PR|PER|REC|SPSD|OBSL|RET)|(?<type>D?NOTE|TR))[\s/-])?
        (?<code>\w+(?:[+-][\w.]+)*?)
        (?:-(?<date>\d{8}|\d{6}|\d{4}))?
        (?:/(?<suff>\w+))?(?:$|/)
      }xi =~ docnumber
      entry = { code: code }
      entry[:stage] = stage if stage
      entry[:type] = type if type && type != "TR"
      entry[:date] = date if date
      entry[:suff] = suff if suff
      new(**entry)
    end

    #
    # Compare document identifiers against Hash ID representation.
    #
    # @param [Hash] other hash of document identifier parts
    #
    # @return [Boolean] true if document identifiers are same
    #
    def ==(other) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      other[:code].casecmp?(code) && other[:stage] == stage && other[:type] == type &&
        (date.nil? || other[:date] == date) && (suff.nil? || other[:suff]&.casecmp?(suff))
    end

    #
    # Convert docidentifier identifier to hash.
    #
    # @return [Hash] hash of docidentifier parts
    #
    def to_hash
      PARTS.each_with_object({}) { |part, hash| hash[part] = send part if send part }
    end
  end
end

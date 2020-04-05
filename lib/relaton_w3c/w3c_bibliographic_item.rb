module RelatonW3c
  class W3cBibliographicItem < RelatonBib::BibliographicItem
    TYPES = %w[
      candidateRecommendation groupNote proposedEditedRecommendation
      proposedRecommendation recommendation retired workingDraft
    ].freeze

    attr_reader :doctype

    # @param doctype [String]
    def initialize(**args)
      if args[:doctype] && !TYPES.include?(args[:doctype])
        warn "[relaton-w3c] invalid document type: #{args[:doctype]}"
      end
      @doctype = args.delete :doctype
      super **args
    end

    # @param builder [Nokogiri::XML::Builder, NilClass]
    # @param opts [Hash]
    # @option opts [TrueClass, FalseClass, NilClass] bibdata
    def to_xml(builder = nil, **opts)
      super builder, **opts do |b|
        if opts[:bibdata] && doctype
          b.ext do |e|
            e.doctype doctype if doctype
          end
        end
      end
    end
  end
end

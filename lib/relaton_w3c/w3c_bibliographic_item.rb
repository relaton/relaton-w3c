module RelatonW3c
  class W3cBibliographicItem < RelatonBib::BibliographicItem
    TYPES = %w[
      candidateRecommendation groupNote proposedEditedRecommendation
      proposedRecommendation recommendation retired workingDraft technicalReport
    ].freeze

    # @param doctype [String]
    def initialize(**args)
      if args[:doctype] && !TYPES.include?(args[:doctype])
        Util.warn "Invalid document type: `#{args[:doctype]}`"
      end
      super
    end

    #
    # Fetch flavor schema version
    #
    # @return [String] flavor schema version
    #
    def ext_schema
      @ext_schema ||= schema_versions["relaton-model-w3c"]
    end
  end
end

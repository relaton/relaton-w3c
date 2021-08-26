module RelatonW3c
  class W3cBibliographicItem < RelatonBib::BibliographicItem
    TYPES = %w[
      candidateRecommendation groupNote proposedEditedRecommendation
      proposedRecommendation recommendation retired workingDraft
    ].freeze

    # @param doctype [String]
    def initialize(**args)
      if args[:doctype] && !TYPES.include?(args[:doctype])
        warn "[relaton-w3c] invalid document type: #{args[:doctype]}"
      end
      super
    end
  end
end

module RelatonW3c
  class DocumentType < RelatonBib::DocumentType
    DOCTYPES = %w[groupNote technicalReport].freeze

    def initialize(type:, abbreviation: nil)
      check_type type
      super
    end

    def check_type(type)
      unless DOCTYPES.include? type
        Util.warn "invalid doctype: `#{type}`"
      end
    end
  end
end

module RelatonW3c
  class W3cBibliographicItem < RelatonBib::BibliographicItem
    # def initialize(**args)
    #   super
    # end

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

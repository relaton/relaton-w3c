module RelatonW3c
  module BibXMLParser
    extend RelatonBib::BibXMLParser
    extend BibXMLParser

    #
    # Return PubID type
    #
    # @param [String] _ docidentifier
    #
    # @return [String] type
    #
    def pubid_type(_)
      "W3C"
    end
  end
end

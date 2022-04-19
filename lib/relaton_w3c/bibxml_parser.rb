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

    def docids(reference, ver)
      ids = super
      ids.reject! &:primary
      id = "W3C #{reference[:target].split('/').last}"
      ids.unshift RelatonBib::DocumentIdentifier.new(id: id, type: "W3C", primary: true)
    end
  end
end

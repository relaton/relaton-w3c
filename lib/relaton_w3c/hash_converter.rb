module RelatonW3c
  module HashConverter
    include RelatonBib::HashConverter
    extend self

    # @param item_hash [Hash]
    # @return [RelatonW3c::W3cBibliographicItem]
    def bib_item(item_hash)
      W3cBibliographicItem.new(**item_hash)
    end

    def create_doctype(**args)
      DocumentType.new(**args)
    end
  end
end

module RelatonW3c
  class HashConverter < RelatonBib::HashConverter
    class << self
      # @param item_hash [Hash]
      # @return [RelatonW3c::W3cBibliographicItem]
      def bib_item(item_hash)
        W3cBibliographicItem.new item_hash
      end
    end
  end
end

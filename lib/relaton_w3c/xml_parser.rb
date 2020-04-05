module RelatonW3c
  class XMLParser < RelatonBib::XMLParser
    class << self
      # @param xml [String]
      # @return [RelatonW3c::W3cBibliographicItem, NilClass]
      def from_xml(xml)
        doc = Nokogiri::XML xml
        doc.remove_namespaces!
        item = doc.at("/bibitem|/bibdata")
        if item
          W3cBibliographicItem.new(item_data(item))
        else
          warn "[relaton-w3c] can't find bibitem or bibdata element in the XML"
        end
      end

      private

      # Override RelatonBib::XMLParser.item_data method.
      # @param item [Nokogiri::XML::Element]
      # @returtn [Hash]
      def item_data(item)
        data = super
        ext = item.at "./ext"
        return data unless ext

        data[:doctype] = ext.at("./doctype")&.text
        data
      end
    end
  end
end

# frozen_string_literal: true

module RelatonW3c
  # Hit.
  class Hit < RelatonBib::Hit
    #
    # Parse page.
    #
    # @param lang [String, NilClass]
    # @return [RelatonW3c::W3cBibliographicItem]
    def fetch(lang = nil)
      @fetch ||= Scrapper.parse_page hit
    end
  end
end

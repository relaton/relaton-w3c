require_relative "ext"

module Relaton
  module W3c
    class Item < Bib::Item
      model Bib::ItemData

      attribute :ext, Ext
    end
  end
end

module Relaton
  module W3c
    class Bibdata < Item
      model ItemData
      include Bib::BibdataShared
    end
  end
end

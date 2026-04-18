module Relaton
  module W3c
    class Bibitem < Item
      model ItemData
      include Bib::BibitemShared
    end
  end
end

module Relaton
  module W3c
    class Doctype < Bib::Doctype
      attribute :content, :string, values: %w[groupNote technicalReport]
    end
  end
end

require_relative "doctype"

module Relaton
  module W3c
    class Ext < Bib::Ext
      attribute :doctype, Doctype
    end
  end
end

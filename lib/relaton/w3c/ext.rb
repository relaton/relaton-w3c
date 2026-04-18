require_relative "doctype"

module Relaton
  module W3c
    class Ext < Bib::Ext
      attribute :doctype, Doctype

      def get_schema_version = Relaton.schema_versions["relaton-model-w3c"]
    end
  end
end

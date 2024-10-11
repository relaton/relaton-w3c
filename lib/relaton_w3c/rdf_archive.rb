module RelatonW3c
  class RDFArchive
    def initialize(file = "archive.rdf")
      @file = file
    end

    #
    # Get RDF data from the updated archive file.
    #
    # @return [RDF::Repository]
    #
    def get_data
      if !File.exist?(@file) || File.mtime(@file) < Time.now - 86_400
        get_archive
        update_archive
      end
      RDF::Repository.load(@file)
    end

    private

    def update_archive
      # Load the older RDF/XML file
      older = Nokogiri::XML File.read(@file, encoding: "UTF-8")

      # Load the newer RDF/XML file
      url = "http://www.w3.org/2002/01/tr-automation/tr.rdf"
      newer = Nokogiri::XML OpenURI.open_uri(url).read

      # Create a hash to store rdf:about attributes from the newer file
      newer_elements = {}
      newer.root.element_children.each do |element|
        rdf_about = element.attribute('about')&.value
        newer_elements[rdf_about] = element if rdf_about
      end

      # Replace elements in the older document
      older.root.element_children.each do |element|
        rdf_about = element.attribute('about')&.value
        if rdf_about && newer_elements[rdf_about]
          element.replace(newer_elements[rdf_about])
          newer_elements.delete(rdf_about)
        end
      end

      # Add remaining new elements to the older document
      newer_elements.each_value do |element|
        older.root.add_child(element)
      end

      # Add new namespaces from the newer document to the older document
      newer.root.namespace_definitions.each do |ns|
        unless older.root.namespace_definitions.any? { |old_ns| old_ns.href == ns.href }
          older.root.add_namespace_definition(ns.prefix, ns.href)
        end
      end
      File.write @file, older.to_xml, encoding: "UTF-8"
    end

    def get_archive
      unless File.exist? @file
        url = "https://raw.githubusercontent.com/relaton/relaton-data-w3c/refs/heads/main/archive.rdf"
        File.write @file, OpenURI.open_uri(url).read, encoding: "UTF-8"
      end
    end
  end
end

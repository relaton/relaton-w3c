module RelatonW3c
  class DataParser
    include RelatonW3c::RateLimitHandler

    USED_TYPES = %w[WD NOTE PER PR REC CR].freeze

    DOCTYPES = {
      "TR" => "technicalReport",
      "NOTE" => "groupNote",
    }.freeze

    STAGES = {
      "RET" => "Retired",
      "SPSD" => "Superseded Recommendation",
      "OBSL" => "Obsoleted Recommendation",
      "WD" => "Working Draft",
      "CRD" => "Candidate Recommendation Draft",
      "CR" => "Candidate Recommendation",
      "PR" => "Proposed Recommendation",
      "PER" => "Proposed Edited Recommendation",
      "REC" => "Recommendation",
    }.freeze

    #
    # Document parser initalization
    #
    # @param [W3cApi::Models::SpecVersion] sol entry from the SPARQL query
    # @param [RelatonW3c::DataFetcher] fetcher data fetcher
    #
    def initialize(spec)
      @spec = spec
    end

    #
    # Initialize document parser and run it
    #
    # @param [W3cApi::Models::SpecVersion] sol entry from the SPARQL query
    #
    # @return [RelatonW3c:W3cBibliographicItem, nil] bibliographic item
    #
    def self.parse(spec)
      new(spec).parse
    end

    #
    # Parse document
    #
    # @return [RelatonW3c:W3cBibliographicItem, nil] bibliographic item
    #
    def parse # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      # return if @sol.respond_to?(:link) && !types_stages.detect { |ts| USED_TYPES.include?(ts) }

      RelatonW3c::W3cBibliographicItem.new(
        type: "standard",
        doctype: parse_doctype,
        language: ["en"],
        script: ["Latn"],
        docstatus: parse_docstatus,
        title: parse_title,
        link: parse_link,
        docid: parse_docid,
        formattedref: parse_formattedref,
        docnumber: identifier,
        series: parse_series,
        date: parse_date,
        relation: parse_relation,
        contributor: parse_contrib,
        editorialgroup: parse_editorialgroup,
      )
    end

    #
    # Extract documetn status
    #
    # @return [RelatonBib::DocumentStatus, nil] dcoument status
    #
    def parse_docstatus
      # stage = types_stages&.detect { |st| STAGES.include?(st) }
      return unless @spec.respond_to?(:status) && @spec.status

      RelatonBib::DocumentStatus.new stage: @spec.status
    end

    #
    # Parse title
    #
    # @return [RelatonBib::TypedTitleStringCollection] title
    #
    def parse_title(spec = @spec)
      t = RelatonBib::TypedTitleString.new content: spec.title
      RelatonBib::TypedTitleStringCollection.new [t]
    end

    def doc_uri(spec = @spec)
      spec.respond_to?(:uri) ? spec.uri : spec.shortlink
    end

    #
    # Parse link
    #
    # @return [Array<RelatonBib::TypedUri>] link
    #
    def parse_link
      [RelatonBib::TypedUri.new(type: "src", content: doc_uri)] # + editor_drafts
    end

    #
    # Parse docidentifier
    #
    # @return [Arra<RelatonBib::DocumentIdentifier>] docidentifier
    #
    def parse_docid
      id = pub_id(doc_uri)
      [RelatonBib::DocumentIdentifier.new(type: "W3C", id: id, primary: true)]
    end

    #
    # Generate PubID
    #
    # @return [String] PubID
    #
    def pub_id(url)
      "W3C #{identifier(url)}"
    end

    #
    # Generate identifier from URL
    #
    # @param [String] link
    #
    # @return [String] identifier
    #
    def identifier(link = doc_uri)
      self.class.parse_identifier(link)
    end

    #
    # Parse identifier from URL
    #
    # @param [String] url URL
    #
    # @return [String] identifier
    #
    def self.parse_identifier(url)
      if /.+\/(\w+(?:[-+][\w.]+)+(?:\/\w+)?)/ =~ url.to_s
        $1.to_s
      else url.to_s.split("/").last
      end
    end

    #
    # Parse series
    #
    # @return [Array<RelatonBib::Series>] series
    #
    def parse_series
      return [] unless type

      title = RelatonBib::TypedTitleString.new content: "W3C #{type}"
      [RelatonBib::Series.new(title: title, number: identifier)]
    end

    #
    # Extract type
    #
    # @return [String] type
    #
    def type
      # there are many types, we need to find the right one
      # @type ||= types_stages&.detect { |t| USED_TYPES.include?(t) } || "technicalReport"
      @type ||= @spec.respond_to?(:status) ? @spec.status : "technicalReport"
    end

    #
    # Parse doctype
    #
    # @return [String, nil] doctype
    #
    def parse_doctype
      t = DOCTYPES[type] || DOCTYPES[type_from_link]
      DocumentType.new(type: t) if t
    end

    #
    # Fetch type from link
    #
    # @return [String, nil] type
    #
    def type_from_link
      # link = @sol.respond_to?(:link) ? @sol.link : @sol.version_of
      @spec.shortlink.strip.match(/www\.w3\.org\/(TR)/)&.to_a&.fetch 1
    end

    #
    # Parse date
    #
    # @return [Array<RelatonBib::BibliographicDate>] date
    #
    def parse_date
      return [] unless @spec.respond_to?(:date)

      [RelatonBib::BibliographicDate.new(type: "published", on: @spec.date.to_date.to_s)]
    end

    #
    # Parse relation
    #
    # @return [Array<RelatonBib::DocumentRelation>] relation
    #
    def parse_relation
      if @spec.links.respond_to?(:version_history)
        version_history = realize @spec.links.version_history
        version_history.links.spec_versions.map { |version| create_relation(version, "hasEdition") }
      else
        relations
      end
    end

    #
    # Create relations
    #
    # @return [Array<RelatonBib::DocumentRelation>] relations
    #
    def relations # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      rels = []
      rels << create_relation(@spec.links.specification, "editionOf") if @spec.links.respond_to?(:specification)
      if @spec.links.respond_to?(:predecessor_versions) && @spec.links.predecessor_versions
        predecessor_versions = realize @spec.links.predecessor_versions
        predecessor_versions.links.predecessor_versions.each do |version|
          rels << create_relation(version, "obsoletes")
        end
      end
      if @spec.links.respond_to?(:successor_versions) && @spec.links.successor_versions
        successor_versions = realize @spec.links.successor_versions
        successor_versions.links.successor_versions.each do |version|
          rels << create_relation(version, "updatedBy", "errata")
        end
      end
      rels
    end

    #
    # Create relation
    #
    # @param [String] url relation URL
    # @param [String] type relation type
    # @param [String, nil] desc relation description
    #
    # @return [RelatonBib::DocumentRelation] <description>
    #
    def create_relation(version, type, desc = nil)
      version_spec = realize version
      url = doc_uri(version_spec)
      id = pub_id(url)
      # fref = RelatonBib::FormattedRef.new content: id
      title = parse_title(version_spec)
      docid = RelatonBib::DocumentIdentifier.new(type: "W3C", id: id, primary: true)
      link = [RelatonBib::TypedUri.new(type: "src", content: url)]
      bib = W3cBibliographicItem.new title: title, docid: [docid], link: link
      dsc = RelatonBib::FormattedString.new content: desc if desc
      RelatonBib::DocumentRelation.new(type: type, bibitem: bib, description: dsc)
    end

    #
    # Parse formattedref
    #
    # @return [RelatonBib::FormattedRef] formattedref
    #
    def parse_formattedref
      return unless @spec.respond_to?(:uri)

      RelatonBib::FormattedRef.new(content: pub_id(@spec.uri))
    end

    #
    # Parse contributor
    #
    # @return [Array<RelatonBib::ContributionInfo>] contributor
    #
    def parse_contrib # rubocop:disable Metrics/MethodLength
      publisher = RelatonBib::Organization.new(
        name: "World Wide Web Consortium", abbreviation: "W3C", url: "https://www.w3.org/"
      )
      contribs = [RelatonBib::ContributionInfo.new(entity: publisher, role: [type: "publisher"])]

      if @spec.links.respond_to?(:editors)
        editors = realize @spec.links.editors
        editors.links.editors&.each do |ed|
          editor = create_editor(ed)
          contribs << editor if editor
        end
      end

      contribs
    end

    def create_editor(unrealized_editor)
      editor = realize unrealized_editor
      return unless editor

      surname = RelatonBib::LocalizedString.new(editor.family, "en", "Latn")
      forename = RelatonBib::Forename.new(content: editor.given, language: "en", script: "Latn")
      name = RelatonBib::FullName.new surname: surname, forename: [forename]
      person = RelatonBib::Person.new name: name
      RelatonBib::ContributionInfo.new(entity: person, role: [type: "editor"])
    end

    #
    # Parse editorialgroup
    #
    # @return [RelatonBib::EditorialGroup] editorialgroup
    #
    def parse_editorialgroup # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      return unless @spec.links.respond_to?(:deliverers)

      deliverers = realize @spec.links.deliverers
      return unless deliverers.links.deliverers

      tc = deliverers.links.deliverers.map do |edg|
        wg = RelatonBib::WorkGroup.new(name: edg.title)
        RelatonBib::TechnicalCommittee.new(wg)
      end

      RelatonBib::EditorialGroup.new tc
    end
  end
end

module RelatonW3c
  class DataParser
    USED_TYPES = %w[WD NOTE PER PR REC CR].freeze

    DOCTYPES = {
      "TR" => "technicalReport",
      "NOTE" => "groupNote",
    }.freeze

    STAGES = {
      "RET" => "retired",
      "SPSD" => "supersededRecommendation",
      "OBSL" => "obsoletedRecommendation",
      "WD" => "workingDraft",
      "CRD" => "candidateRecommendationDraft",
      "CR" => "candidateRecommendation",
      "PR" => "proposedRecommendation",
      "PER" => "proposedEditedRecommendation",
      "REC" => "recommendation",
    }.freeze

    #
    # Document parser initalization
    #
    # @param [RDF::Query::Solution] sol entry from the SPARQL query
    # @param [RelatonW3c::DataFetcher] fetcher data fetcher
    #
    def initialize(rdf, sol, fetcher)
      @rdf = rdf
      @sol = sol
      @fetcher = fetcher
    end

    #
    # Initialize document parser and run it
    #
    # @param [RDF::Query::Solution] sol entry from the SPARQL query
    # @param [RelatonW3c::DataFetcher] fetcher data fetcher
    #
    # @return [RelatonW3c:W3cBibliographicItem, nil] bibliographic item
    #
    def self.parse(rdf, sol, fetcher)
      new(rdf, sol, fetcher).parse
    end

    #
    # Parse document
    #
    # @return [RelatonW3c:W3cBibliographicItem, nil] bibliographic item
    #
    def parse # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      return if @sol.respond_to?(:link) && !types_stages.detect { |ts| USED_TYPES.include?(ts) }

      RelatonW3c::W3cBibliographicItem.new(
        type: "standard",
        doctype: parse_doctype,
        fetched: Date.today.to_s,
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
      stage = types_stages&.detect { |st| STAGES.include?(st) }
      RelatonBib::DocumentStatus.new stage: STAGES[stage] if stage
    end

    #
    # Parse title
    #
    # @return [RelatonBib::TypedTitleStringCollection] title
    #
    def parse_title
      content = if @sol.respond_to?(:title) then @sol.title.to_s
                else document_versions.max_by { |dv| dv.date.to_s }.title.to_s
                end
      t = RelatonBib::TypedTitleString.new content: content
      RelatonBib::TypedTitleStringCollection.new [t]
    end

    #
    # Parse link
    #
    # @return [Array<RelatonBib::TypedUri>] link
    #
    def parse_link
      link = @sol.respond_to?(:link) ? @sol.link : @sol.version_of
      [RelatonBib::TypedUri.new(type: "src", content: link.to_s.strip)] + editor_drafts
    end

    #
    # Parse docidentifier
    #
    # @return [Arra<RelatonBib::DocumentIdentifier>] docidentifier
    #
    def parse_docid
      id = @sol.respond_to?(:link) ? pub_id(@sol.link) : pub_id(@sol.version_of)
      [RelatonBib::DocumentIdentifier.new(type: "W3C", id: id, primary: true)]
    end

    #
    # Generate PubID
    #
    # @return [RDF::URI] PubID
    #
    def pub_id(url)
      "W3C #{identifier(url)}"
    end

    #
    # Generate identifier from URL
    #
    # @param [RDF::URI, nil] link
    #
    # @return [String] identifier
    #
    def identifier(link = nil)
      url = link || (@sol.respond_to?(:link) ? @sol.link : @sol.version_of)
      self.class.parse_identifier(url.to_s.strip)
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
      # thre are many types, we need to find the right one
      @type ||= types_stages&.detect { |t| USED_TYPES.include?(t) } || "technicalReport"
    end

    #
    # Fetches types and stages
    #
    # @return [Array<String>] types and stages
    #
    def types_stages
      @types_stages ||= begin
        sse = @sol.respond_to?(:link) ? versioned_types_stages : unversioned_types_stages
        @rdf.query(sse).map { |s| s.type.to_s.split("#").last }
      end
    end

    #
    # Create SPARQL query for versioned types and stages
    #
    # @return [SPARQL::Algebra::Operator::Prefix] SPARQL query
    #
    def versioned_types_stages
      SPARQL.parse(%(
        PREFIX : <http://www.w3.org/2001/02pd/rec54#>
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        SELECT ?type
        WHERE {
          { <#{@sol.link.to_s.strip}> rdf:type ?type }
        }
      ))
    end

    #
    # Create SPARQL query for unversioned types and stages
    #
    # @return [SPARQL::Algebra::Operator::Prefix] SPARQL query
    #
    def unversioned_types_stages
      SPARQL.parse(%(
        PREFIX : <http://www.w3.org/2001/02pd/rec54#>
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX doc: <http://www.w3.org/2000/10/swap/pim/doc#>
        SELECT ?type
        WHERE {
          ?link doc:versionOf <#{@sol.version_of}>; rdf:type ?type .
          FILTER ( isURI(?link) && STR(?link) != <#{@sol.version_of}> )
        }
      ))
    end

    #
    # Parse doctype
    #
    # @return [String, nil] doctype
    #
    def parse_doctype
      DOCTYPES[type] || DOCTYPES[type_from_link]
    end

    #
    # Fetch type from link
    #
    # @return [String, nil] type
    #
    def type_from_link
      link = @sol.respond_to?(:link) ? @sol.link : @sol.version_of
      link.to_s.strip.match(/www\.w3\.org\/(TR)/)&.to_a&.fetch 1
    end

    #
    # Parse date
    #
    # @return [Array<RelatonBib::BibliographicDate>] date
    #
    def parse_date
      return [] unless @sol.respond_to?(:date)

      [RelatonBib::BibliographicDate.new(type: "published", on: @sol.date.to_s)]
    end

    #
    # Parse relation
    #
    # @return [Array<RelatonBib::DocumentRelation>] relation
    #
    def parse_relation
      if @sol.respond_to?(:link)
        relations
      else
        document_versions.map { |r| create_relation(r.link.to_s.strip, "hasEdition") }
      end
    end

    #
    # Create relations
    #
    # @return [Array<RelatonBib::DocumentRelation>] relations
    #
    def relations # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      {
        "doc:obsoletes" => { type: "obsoletes" },
        "mat:hasErrata" => { type: "updatedBy", description: "errata" },
        # "mat:hasTranslations" => "hasTranslation",
        # "mat:hasImplReport" => "hasImpReport",
        ":previousEdition" => { type: "editionOf" },
      }.reduce([]) do |acc, (predicate, tp)|
        acc + relation_query(predicate).map do |r|
          create_relation(r.rel.to_s, tp[:type], tp[:description])
        end
      end
    end

    #
    # Parse editor drafts relation
    #
    # @return [Array<RelatonBib::DocumentRelation>] relation
    #
    def editor_drafts # rubocop:disable Metrics/MethodLength
      return [] unless @sol.respond_to?(:link)

      sse = SPARQL.parse(%(
        PREFIX : <http://www.w3.org/2001/02pd/rec54#>
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        SELECT ?latest
        WHERE { <#{@sol.link.to_s.strip}> :ED ?latest . }
      ))
      @rdf.query(sse).map do |s|
        RelatonBib::TypedUri.new(type: "current", content: s.latest.to_s.strip)
      end
    end

    #
    # Query for relations
    #
    # @param [String] predicate relation type
    #
    # @return [RDF::Query::Solutions] query result
    #
    def relation_query(predicate)
      sse = SPARQL.parse(%(
        PREFIX : <http://www.w3.org/2001/02pd/rec54#>
        PREFIX doc: <http://www.w3.org/2000/10/swap/pim/doc#>
        PREFIX mat: <http://www.w3.org/2002/05/matrix/vocab#>
        SELECT ?rel
        WHERE { <#{@sol.link.to_s.strip}> #{predicate} ?rel . }
      ))
      @rdf.query(sse).order_by(:rel)
    end

    #
    # Query document versions relations
    #
    # @return [Array<RDF::Query::Solution>] query results
    #
    def document_versions # rubocop:disable Metrics/MethodLength
      @document_versions ||= version_of.each_with_object([]) do |s, acc|
        sse = SPARQL.parse(%(
          PREFIX : <http://www.w3.org/2001/02pd/rec54#>
          PREFIX dc: <http://purl.org/dc/elements/1.1/>
          PREFIX doc: <http://www.w3.org/2000/10/swap/pim/doc#>
          PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
          SELECT ?link ?title ?date
          WHERE {
            ?link doc:versionOf <#{s.version_of}> ;
            dc:title ?title ;
            dc:date ?date .
          }
        ))
        @rdf.query(sse).each { |r| acc << r }
      end
    end

    #
    # Query for document versions
    #
    # @return [RDF::Query::Solutions] query results
    #
    def version_of
      return [@sol] unless @sol.respond_to?(:link)

      sse = SPARQL.parse(%(
        PREFIX doc: <http://www.w3.org/2000/10/swap/pim/doc#>
        SELECT ?version_of
        WHERE {
          <#{@sol.link.to_s.strip}> doc:versionOf ?version_of .
          FILTER ( isURI(?version_of) && <#{@sol.link.to_s.strip}> != str(?version_of) )
        }
      ))
      @rdf.query(sse)
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
    def create_relation(url, type, desc = nil)
      id = pub_id(url)
      fref = RelatonBib::FormattedRef.new content: id
      docid = RelatonBib::DocumentIdentifier.new(type: "W3C", id: id, primary: true)
      bib = W3cBibliographicItem.new formattedref: fref, docid: [docid]
      dsc = RelatonBib::FormattedString.new content: desc if desc
      RelatonBib::DocumentRelation.new(type: type, bibitem: bib, description: dsc)
    end

    #
    # Parse formattedref
    #
    # @return [RelatonBib::FormattedRef] formattedref
    #
    def parse_formattedref
      return if @sol.respond_to?(:link)

      RelatonBib::FormattedRef.new(content: pub_id(@sol.version_of))
    end

    #
    # Parse contributor
    #
    # @return [Array<RelatonBib::ContributionInfo>] contributor
    #
    def parse_contrib # rubocop:disable Metrics/MethodLength
      return [] unless @sol.respond_to?(:link)

      sse = SPARQL.parse(%(
        PREFIX : <http://www.w3.org/2001/02pd/rec54#>
        PREFIX contact: <http://www.w3.org/2000/10/swap/pim/contact#>
        SELECT ?full_name
        WHERE {
          <#{@sol.link.to_s.strip}> :editor/contact:fullName ?full_name
        }
      ))
      @rdf.query(sse).order_by(:full_name).map do |ed|
        cn = RelatonBib::LocalizedString.new(ed.full_name.to_s, "en", "Latn")
        n = RelatonBib::FullName.new completename: cn
        p = RelatonBib::Person.new name: n
        RelatonBib::ContributionInfo.new entity: p, role: [type: "editor"]
      end
    end

    #
    # Parse editorialgroup
    #
    # @return [RelatonBib::EditorialGroup] editorialgroup
    #
    def parse_editorialgroup # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      return unless @sol.respond_to?(:link)

      sse = SPARQL.parse(%(
        PREFIX org: <http://www.w3.org/2001/04/roadmap/org#>
        PREFIX contact: <http://www.w3.org/2000/10/swap/pim/contact#>
        SELECT ?home_page
        WHERE {
          <#{@sol.link.to_s.strip}> org:deliveredBy/contact:homePage ?home_page
        }
      ))
      res = @rdf.query(sse).order_by(:home_page)
      tc = res.each_with_object([]) do |edg, obj|
        group_path = edg.home_page.to_s.sub(/^https?:\/\//, "").sub(/\/$/, "")
        wg = @fetcher.group_names[group_path]
        if wg
          rwg = RelatonBib::WorkGroup.new name: wg["name"]
          obj << RelatonBib::TechnicalCommittee.new(rwg)
        else
          warn "Working group name not found for #{edg.home_page}"
        end
      end
      RelatonBib::EditorialGroup.new tc
    end
  end
end

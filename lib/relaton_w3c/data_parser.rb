module RelatonW3c
  class DataParser
    #
    # Document parser initalization
    #
    # @param [RDF::Query::Solution] sol entry from the SPARQL query
    # @param [RelatonW3c::DataFetcher] fetcher data fetcher
    #
    def initialize(sol, fetcher)
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
    def self.parse(sol, fetcher)
      new(sol, fetcher).parse
    end

    #
    # Parse document
    #
    # @return [RelatonW3c:W3cBibliographicItem, nil] bibliographic item
    #
    def parse # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      return unless @fetcher.class::USED_TYPES.include? type

      RelatonW3c::W3cBibliographicItem.new(
        type: "standard",
        doctype: parse_doctype,
        fetched: Date.today.to_s,
        language: ["en"],
        script: ["Latn"],
        title: parse_title,
        link: parse_link,
        docid: parse_docid,
        docnumber: identifier(@sol.link.to_s),
        series: parse_series,
        date: parse_date,
        relation: parse_relation,
        contributor: parse_contrib,
        editorialgroup: parse_editorialgroup,
      )
    end

    #
    # Parse title
    #
    # @return [RelatonBib::TypedTitleStringCollection] title
    #
    def parse_title
      t = RelatonBib::TypedTitleString.new title: @sol.title.to_s
      RelatonBib::TypedTitleStringCollection.new [t]
    end

    #
    # Parse link
    #
    # @return [Array<RelatonBib::TypedUri>] link
    #
    def parse_link
      [RelatonBib::TypedUri.new(type: "src", content: @sol.link.to_s)]
    end

    #
    # Parse docidentifier
    #
    # @return [Arra<RelatonBib::DocumentIdentifier>] docidentifier
    #
    def parse_docid
      id = pub_id(@sol.link.to_s)
      [RelatonBib::DocumentIdentifier.new(type: "W3C", id: id)]
    end

    #
    # Generate PubID
    #
    # @param [String] url url
    #
    # @return [String] PubID
    #
    def pub_id(url)
      "W3C #{identifier(url)}"
    end

    def identifier(url)
      /.+\/(\w+(?:-[\w.]+)+(?:\/\w+)?)/.match(url)[1].to_s
    end

    #
    # Parse series
    #
    # @return [Array<RelatonBib::Series>] series
    #
    def parse_series
      title = RelatonBib::TypedTitleString.new content: "W3C #{type}"
      [RelatonBib::Series.new(title: title, number: identifier(@sol.link.to_s))]
    end

    def type # rubocop:disable Metrics/MethodLength
      @type ||= begin
        sse = SPARQL.parse(%(
          PREFIX : <http://www.w3.org/2001/02pd/rec54#>
          PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
          SELECT ?type
          WHERE {
            { <#{@sol.link}> rdf:type ?type }
          }
        ))
        tps = @fetcher.data.query(sse).map { |s| s.type.to_s.split("#").last }
        tps.detect { |t| Scrapper::DOCTYPES.key?(t) }
      end
    end

    #
    # Parse doctype
    #
    # @return [Strinf] doctype
    #
    def parse_doctype
      Scrapper::DOCTYPES[type]
    end

    def parse_date
      [RelatonBib::BibliographicDate.new(type: "published", on: @sol.date.to_s)]
    end

    #
    # Parse relation
    #
    # @return [Array<RelatonBib::DocumentRelation>] relation
    #
    def parse_relation # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      sse = SPARQL.parse(%(
        PREFIX doc: <http://www.w3.org/2000/10/swap/pim/doc#>
        SELECT ?obsoletes
        WHERE {
          VALUES ?p { doc:obsoletes }
          { <#{@sol.link}> ?p ?obsoletes }
        }
      ))
      @fetcher.data.query(sse).order_by(:obsoletes).map do |r|
        tp, url = r.to_h.first
        fr = RelatonBib::LocalizedString.new pub_id(url.to_s)
        bib = W3cBibliographicItem.new formattedref: fr
        RelatonBib::DocumentRelation.new(type: tp.to_s, bibitem: bib)
      end
    end

    #
    # Parse contributor
    #
    # @return [Array<RelatonBib::ContributionInfo>] contributor
    #
    def parse_contrib # rubocop:disable Metrics/MethodLength
      sse = SPARQL.parse(%(
        PREFIX : <http://www.w3.org/2001/02pd/rec54#>
        PREFIX contact: <http://www.w3.org/2000/10/swap/pim/contact#>
        SELECT ?full_name
        WHERE {
          <#{@sol.link}> :editor/contact:fullName ?full_name
        }
      ))
      @fetcher.data.query(sse).order_by(:full_name).map do |ed|
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
      sse = SPARQL.parse(%(
        PREFIX org: <http://www.w3.org/2001/04/roadmap/org#>
        PREFIX contact: <http://www.w3.org/2000/10/swap/pim/contact#>
        SELECT ?home_page
        WHERE {
          <#{@sol.link}> org:deliveredBy/contact:homePage ?home_page
        }
      ))
      res = @fetcher.data.query(sse).order_by(:home_page)
      tc = res.each_with_object([]) do |edg, obj|
        wg = @fetcher.group_names[edg.home_page.to_s.sub(/\/$/, "")]
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

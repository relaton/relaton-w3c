module RelatonW3c
  class Scrapper
    class << self
      DOCTYPES = {
        "CR" => "candidateRecommendation",
        "NOTE" => "groupNote",
        "PER" => "proposedEditedRecommendation",
        "PR" => "proposedRecommendation",
        "REC" => "recommendation",
        "RET" => "retired",
        "WD" => "workingDraft",
      }.freeze

      # @param hit [Hash]
      # @return [RelatonW3c::W3cBibliographicItem]
      def parse_page(hit) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        resp = Net::HTTP.get_response URI.parse(hit["link"])
        doc = resp.code == "200" ? Nokogiri::HTML(resp.body) : nil
        W3cBibliographicItem.new(
          type: "standard",
          fetched: Date.today.to_s,
          language: ["en"],
          script: ["Latn"],
          title: fetch_title(hit, doc),
          abstract: fetch_abstract(doc),
          link: fetch_link(hit),
          date: fetch_date(hit, doc),
          doctype: fetch_doctype(hit, doc),
          contributor: fetch_contributor(hit, doc),
          relation: fetch_relation(doc),
          keyword: hit["keyword"]
        )
      end

      private

      # @param hit [Hash]
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<RelatonBib::TypedTitleString>]
      def fetch_title(hit, doc) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        titles = []
        if doc
          title = doc.at("//h1[contains(@id, 'title')]")&.text
          titles << { content: title, type: "main" } if title
          subtitle = doc.at(
            "//h2[@id='subtitle']|//p[contains(@class, 'subline')]"
          )&.text
          titles << { content: subtitle, tipe: "subtitle" } if subtitle
        elsif hit["title"]
          titles << { content: hit["title"], type: "main" }
        end
        titles.map do |t|
          title = RelatonBib::FormattedString.new(
            content: t[:content], language: "en", script: "Latn"
          )
          RelatonBib::TypedTitleString.new(type: t[:type], title: title)
        end
      end

      # @param doc [Nokogiri::HTML::Document, NilClass]
      # @return [Array<RelatonBib::FormattedString>]
      def fetch_abstract(doc)
        return [] unless doc

        content = doc.at("//h2[.='Abstract']/following-sibling::p").text
        [RelatonBib::FormattedString.new(content: content, language: "en",
                                         script: "Latn")]
      end

      # @param hit [Hash]
      # @return [Array<RelatonBib::TypedUri>]
      def fetch_link(hit)
        [RelatonBib::TypedUri.new(type: "src", content: hit["link"])]
      end

      # @param hit [Hash]
      # @param doc [Nokogiri::HTML::Document, NilClass]
      # @return [Array<RelatonBib::BibliographicDate>]
      def fetch_date(hit, doc)
        on = hit["datepub"] || doc&.at("//h2/time[@datetime]")&.attr(:datetime)
        on ||= fetch_date1(doc) || fetch_date2(doc)
        [RelatonBib::BibliographicDate.new(type: "published", on: on)] if on
      end

      # @param doc [Nokogiri::HTML::Document, NilClass]
      # @return [String]
      def fetch_date1(doc)
        d = doc&.at("//h2[@property='dc:issued']")&.attr(:content)
        d&.match(/\d{4}-\d{2}-\d{2}/)&.to_s
      end

      # @param doc [Nokogiri::HTML::Document, NilClass]
      # @return [String]
      def fetch_date2(doc)
        d = doc&.at("//h2[contains(@id, 'w3c-recommendation')]")
        return unless d

        Date.parse(d.attr(:id.match(/\d{2}-\w+-\d{4}/).to_s)).to_s
      end

      # @param hit [Hash]
      # @param doc [Nokogiri::HTML::Document, NilClass]
      # @return [String]
      def fetch_doctype(hit, doc)
        if hit["type"]
          DOCTYPES[hit["type"]]
        elsif doc
          type = HitCollection::TYPES.detect do |_k, v|
            doc.at("//h2[contains(., '#{v}')]/time[@datetime]")
          end
          DOCTYPES[type&.first]
        end
      end

      # @param hit [Hash]
      # @param doc [Nokogiri::HTML::Document, NilClass]
      # @return [Array<RelatonBib::ContributionInfo>]
      def fetch_contributor(hit, doc) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        if doc
          editors = find_contribs(doc, "Editors").reduce([]) do |mem, ed|
            c = parse_contrib ed, "editor"
            mem << c if c
            mem
          end
          contribs = find_contribs(doc, "Authors").reduce(editors) do |mem, ath|
            ed = mem.detect { |e| e[:id] && e[:id] == ath["data-editor-id"] }
            if ed
              ed[:role] << { type: "author" }
            else
              mem << parse_contrib(ath, "author")
            end
            mem
          end
          contribs.map { |c| contrib_info c }
        else
          hit["editor"].map do |ed|
            contrib_info name: ed, role: [{ type: "editor" }]
          end
        end
      end

      # @param doc [Nokogiri::NTML::Document]
      # @param type [String]
      # @return [Array<Nokogiri::XML::Element]
      def find_contribs(doc, type)
        doc.xpath("//dt[contains(.,'#{type}')]/following-sibling::dd"\
                  "[preceding-sibling::dt[1][contains(.,'#{type}')]]")
      end

      # @param element [Nokogiri::XML::Element]
      # @param type [String]
      # @return [Hash]
      def parse_contrib(element, type)
        p = element.at("a")
        return unless p

        contrib = {
          name: p.text,
          url: p[:href],
          role: [{ type: type }],
          id: element["data-editor-id"],
        }
        org = element.at("a[2]")
        contrib[:org] = { name: org.text, url: org[:href] } if org
        contrib
      end

      # @param name [String]
      # @param url [String, NilClass]
      # @param role [Array<Hash>]
      # @parma org [Hash]
      # @return [RelatonBib::ContributionInfo]
      def contrib_info(**args)
        completename = RelatonBib::LocalizedString.new(args[:name])
        name = RelatonBib::FullName.new completename: completename
        af = []
        if args[:org]
          org = RelatonBib::Organization.new args[:org]
          af << RelatonBib::Affiliation.new(organization: org)
        end
        en = RelatonBib::Person.new name: name, url: args[:url], affiliation: af
        RelatonBib::ContributionInfo.new entity: en, role: args[:role]
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<RelatonBib::DocumentRelation>]
      def fetch_relation(doc)
        return [] unless doc && (link = recommendation_link(doc))

        hit = { "link" => link }
        item = parse_page hit
        [RelatonBib::DocumentRelation.new(type: "obsoletedBy", bibitem: item)]
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [String, NilClass]
      def recommendation_link(doc)
        recom = doc.at("//dt[.='Latest Recommendation:']",
                       "//dt[.='Previous Recommendation:']")
        return unless recom

        recom.at("./following-sibling::dd/a")[:href]
      end
    end
  end
end

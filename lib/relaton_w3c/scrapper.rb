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
        "WD" => "workingDraft"
      }.freeze

      # @param hit [Hash]
      # @return [RelatonW3c::W3cBibliographicItem]
      def parse_page(hit)
        doc = nil
        if hit["link"] =~ Regexp.new(HitCollection::DOMAIN)
          resp = Net::HTTP.get URI.parse(hit["link"])
          doc = Nokogiri::HTML resp
        end
        W3cBibliographicItem.new(
          type: "standard",
          fetched: Date.today.to_s,
          language: ["en"],
          script: ["Latn"],
          title: title(hit),
          abstract: abstract(doc),
          link: link(hit),
          date: date(hit),
          doctype: doctype(hit),
          contributor: contributor(hit, doc),
          keyword: keyword(hit),
        )
      end

      private

      # @param hit [Hash]
      # @return [Array<RelatonBib::TypedTitleString>]
      def title(hit)
        t = RelatonBib::FormattedString.new content: hit["title"], language: "en", script: "Latn"
        [RelatonBib::TypedTitleString.new(type: "main", title: t)]
      end

      # @param doc [Nokogiri::HTML::Document, NilClass]
      # @return [Array<RelatonBib::FormattedString>]
      def abstract(doc)
        return [] unless doc

        content = doc.at("//h2[.='Abstract']/following-sibling::p").text
        [RelatonBib::FormattedString.new(content: content, language: "en", script: "Latn")]
      end

      # @param hit [Hash]
      # @return [Array<RelatonBib::TypedUri>]
      def link(hit)
        [RelatonBib::TypedUri.new(type: "src", content: hit["link"])]
      end

      # @param hit [Hash]
      # @return [Array<RelatonBib::BibliographicDate>]
      def date(hit)
        [RelatonBib::BibliographicDate.new(type: "published", on: hit["datepub"])]
      end

      # @param hit [Hash]
      # @return [String]
      def doctype(hit)
        DOCTYPES[hit["type"]]
      end

      # @param hit [Hash]
      # @param doc [Nokogiri::HTML::Document, NilClass]
      # @return [Array<RelatonBib::ContributionInfo>]
      def contributor(hit, doc)
        if doc
          editors = find_contribs(doc, "Editors").map { |ed| parse_contrib ed, "editor" }
          contribs = find_contribs(doc, "Authors").reduce(editors) do |mem, athr|
            ed = mem.detect { |e| e[:id] && e[:id] == athr["data-editor-id"] }
            if ed
              ed[:role] << { type: "author" }
            else
              mem << parse_contrib(athr, "author")
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
        aff = []
        if args[:org]
          org = RelatonBib::Organization.new args[:org]
          aff << RelatonBib::Affiliation.new(organization: org)
        end
        en = RelatonBib::Person.new name: name, url: args[:url], affiliation: aff
        RelatonBib::ContributionInfo.new entity: en, role: args[:role]
      end

      # @param hit [Hash]
      # @return [Array<RelatonBib::LocalizedString>]
      def keyword(hit)
        hit["keyword"].map do |kw|
          RelatonBib::LocalizedString.new kw, "en", "Latn"
        end
      end
    end
  end
end
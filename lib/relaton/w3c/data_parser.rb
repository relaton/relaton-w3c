module Relaton
  module W3c
    class DataParser
      include Relaton::W3c::SafeRealize

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
      # @param [W3cApi::Models::SpecVersion] spec
      #
      ERROR_KEYS = %i[status title doc_uri formattedref series date
                      relation contributor doctype].freeze

      def initialize(spec, errors = {})
        @spec = spec
        @errors = errors
        ERROR_KEYS.each { |k| @errors[k] = true unless @errors.key?(k) }
      end

      #
      # Initialize document parser and run it
      #
      # @param [W3cApi::Models::SpecVersion] spec
      #
      # @return [Relaton::W3c::ItemData, nil] bibliographic item
      #
      def self.parse(spec, errors = {})
        new(spec, errors).parse
      end

      #
      # Parse document
      #
      # @return [Relaton::W3c::ItemData] bibliographic item
      #
      def parse # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        ItemData.new(
          type: "standard",
          language: ["en"],
          script: ["Latn"],
          status: parse_status,
          title: parse_title,
          source: parse_source,
          docidentifier: parse_docid,
          formattedref: parse_formattedref,
          docnumber: identifier,
          series: parse_series,
          date: parse_date,
          relation: parse_relation,
          contributor: parse_contrib,
          ext: parse_ext,
        )
      end

      #
      # Parse ext with doctype
      #
      # @return [Ext, nil] ext
      #
      def parse_ext
        dt = parse_doctype
        result = Ext.new(doctype: dt, flavor: "w3c")
        result
      end

      #
      # Extract document status
      #
      # @return [Bib::Status, nil] document status
      #
      def parse_status
        result = if @spec.respond_to?(:status) && @spec.status
                   Bib::Status.new(stage: Bib::Status::Stage.new(content: @spec.status))
                 end
        @errors[:status] &&= result.nil?
        result
      end

      #
      # Parse title
      #
      # @return [Array<Bib::Title>] title
      #
      def parse_title(spec = @spec)
        return [] unless spec&.title && spec.title.strip != ""

        result = [Bib::Title.new(content: spec.title, language: "en", script: "Latn")]
        @errors[:title] &&= result.empty?
        result
      end

      def doc_uri(spec = @spec)
        result = spec.respond_to?(:uri) ? spec.uri : spec.shortlink
        @errors[:doc_uri] &&= result.nil?
        result
      end

      #
      # Parse link
      #
      # @return [Array<Bib::Uri>] link
      #
      def parse_source
        [Bib::Uri.new(type: "src", content: doc_uri)]
      end

      #
      # Parse docidentifier
      #
      # @return [Array<Bib::Docidentifier>] docidentifier
      #
      def parse_docid
        id = pub_id(doc_uri)
        [Bib::Docidentifier.new(type: "W3C", content: id, primary: true)]
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
      # @return [Array<Bib::Series>] series
      #
      def parse_series
        result = if type
                   title = Bib::Title.new(content: "W3C #{type}", language: "en", script: "Latn")
                   [Bib::Series.new(title: [title], number: identifier)]
                 else
                   []
                 end
        @errors[:series] &&= result.empty?
        result
      end

      #
      # Extract type
      #
      # @return [String] type
      #
      def type
        @type ||= @spec.respond_to?(:status) ? @spec.status : "technicalReport"
      end

      #
      # Parse doctype
      #
      # @return [Doctype, nil] doctype
      #
      def parse_doctype
        t = DOCTYPES[type] || DOCTYPES[type_from_link]
        result = Doctype.new(content: t) if t
        @errors[:doctype] &&= result.nil?
        result
      end

      #
      # Fetch type from link
      #
      # @return [String, nil] type
      #
      def type_from_link
        @spec.shortlink.strip.match(/www\.w3\.org\/(TR)/)&.to_a&.fetch 1
      end

      #
      # Parse date
      #
      # @return [Array<Bib::Date>] date
      #
      def parse_date
        result = if @spec.respond_to?(:date)
                   [Bib::Date.new(type: "published", at: @spec.date.to_date.to_s)]
                 else
                   []
                 end
        @errors[:date] &&= result.empty?
        result
      end

      #
      # Parse relation
      #
      # @return [Array<Bib::Relation>] relation
      #
      def parse_relation
        result = if @spec.links.respond_to?(:version_history)
                   version_history = realize @spec.links.version_history
                   version_history&.links&.spec_versions&.map { |version| create_relation(version, "hasEdition") } || []
                 else
                   relations
                 end
        result = result.compact
        @errors[:relation] &&= result.empty?
        result
      end

      #
      # Create relations
      #
      # @return [Array<Bib::Relation>] relations
      #
      def relations # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        rels = []
        rels << create_relation(@spec.links.specification, "editionOf") if @spec.links.respond_to?(:specification)
        if @spec.links.respond_to?(:predecessor_versions) && @spec.links.predecessor_versions
          predecessor_versions = realize @spec.links.predecessor_versions
          predecessor_versions&.links&.predecessor_versions&.each do |version|
            rels << create_relation(version, "obsoletes")
          end
        end
        if @spec.links.respond_to?(:successor_versions) && @spec.links.successor_versions
          successor_versions = realize @spec.links.successor_versions
          successor_versions&.links&.successor_versions&.each do |version|
            rels << create_relation(version, "updatedBy", "errata")
          end
        end
        rels.compact
      end

      #
      # Create relation
      #
      # @param [Object] version version link
      # @param [String] type relation type
      # @param [String, nil] desc relation description
      #
      # @return [Bib::Relation] relation
      #
      def create_relation(version, type, desc = nil)
        version_spec = realize version
        return nil unless version_spec

        url = doc_uri(version_spec)
        id = pub_id(url)
        title = parse_title(version_spec)
        docid = Bib::Docidentifier.new(type: "W3C", content: id, primary: true)
        link = [Bib::Uri.new(type: "src", content: url)]
        bib = ItemData.new(title: title, docidentifier: [docid], source: link)
        dsc = Bib::LocalizedMarkedUpString.new(content: desc) if desc
        Bib::Relation.new(type: type, bibitem: bib, description: dsc)
      end

      #
      # Parse formattedref
      #
      # @return [String, nil] formattedref
      #
      def parse_formattedref
        result = if @spec.respond_to?(:uri)
                   Bib::Formattedref.new(content: pub_id(@spec.uri))
                 end
        @errors[:formattedref] &&= result.nil?
        result
      end

      #
      # Parse contributor
      #
      # @return [Array<Bib::Contributor>] contributor
      #
      def parse_contrib # rubocop:disable Metrics/MethodLength
        contribs = [Bib::Contributor.new(
          organization: create_w3c_org,
          role: [Bib::Contributor::Role.new(type: "publisher")],
        )]

        if @spec.links.respond_to?(:editors)
          editors = realize @spec.links.editors
          editors&.links&.editors&.each do |ed|
            editor = create_editor(ed)
            contribs << editor if editor
          end
        end

        result = contribs + parse_deliverers
        @errors[:contributor] &&= result.empty?
        result
      end

      def create_editor(unrealized_editor)
        editor = realize unrealized_editor
        return unless editor

        surname = Bib::LocalizedString.new(content: editor.family, language: "en", script: "Latn")
        forename = Bib::FullNameType::Forename.new(content: editor.given, language: "en", script: "Latn")
        name = Bib::FullName.new(surname: surname, forename: [forename])
        person = Bib::Person.new(name: name)
        Bib::Contributor.new(
          person: person,
          role: [Bib::Contributor::Role.new(type: "editor")],
        )
      end

      #
      # Parse deliverers as contributors with role "author" and description "committee"
      #
      # @return [Array<Bib::Contributor>] deliverer contributors
      #
      def parse_deliverers # rubocop:disable Metrics/MethodLength
        return [] unless @spec.links.respond_to?(:deliverers)

        deliverers = realize @spec.links.deliverers
        return [] unless deliverers&.links&.deliverers

        deliverers.links.deliverers.map do |edg|
          org = create_w3c_org.tap do |o|
            subdiv_name = Bib::TypedLocalizedString.new(content: edg.title)
            subdiv = Bib::Subdivision.new(name: [subdiv_name], type: "technical-committee")
            o.subdivision = [subdiv]
          end
          role = Bib::Contributor::Role.new(
            type: "author",
            description: [Bib::LocalizedMarkedUpString.new(content: "committee")],
          )
          Bib::Contributor.new(organization: org, role: [role])
        end
      end

      def create_w3c_org
        Bib::Organization.new(
          name: [Bib::TypedLocalizedString.new(content: "World Wide Web Consortium")],
          abbreviation: Bib::LocalizedString.new(content: "W3C"),
          uri: Bib::Uri.new(content: "https://www.w3.org"),
        )
      end
    end
  end
end

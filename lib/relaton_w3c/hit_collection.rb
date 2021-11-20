# frozen_string_literal: true

require "fileutils"
require "yaml"

module RelatonW3c
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    TYPES = {
      "CR" => "Candidate Recommendation",
      "NOTE" => "Group Note",
      "PER" => "Proposed Edited Recommendation",
      "PR" => "Proposed Recommendation",
      "REC" => "Recommendation",
      "RET" => "Retired",
      "WD" => "Working Draft",
    }.freeze
    DOMAIN = "https://www.w3.org"
    DATADIR = File.expand_path(".relaton/w3c", Dir.home).freeze
    DATAFILE = File.expand_path("bibliography.yml", DATADIR).freeze

    # @param ref [String] reference to search
    def initialize(ref)
      %r{
        ^(?:W3C\s)?
        (?<type>(?:CR|NOTE|PER|PR|REC|RET|WD|Candidate\sRecommendation|
          Group\sNote|Proposed\sEdited\sRecommendation|Proposed\sRecommendation|
          Recommendation|Retired|Working\sDraft))? # type
        \s?
        (?<title_date>.+) # title_date
      }x =~ ref
      super
      @array = from_yaml title_date, type
    end

    private

    #
    # Fetch data form yaml
    #
    # @param title_date [String]
    # @param type [String]
    # @return [Array<Hash>]
    def from_yaml(title_date, type) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
      /(?<title>.+)\s(?<date>\d{4}-\d{2}-\d{2})$/ =~ title_date
      title ||= title_date
      result = data.select do |hit|
        (hit["title"].casecmp?(title) ||
          hit["link"].split("/").last.match?(/-#{title}-/)) &&
          type_date_filter(hit, type, date)
      end
      if result.empty?
        result = data.select { |h| h["link"].split("/").last.match?(/#{title}/) }
      end
      result.map { |h| Hit.new(h, self) }
    end

    # @param hit [Hash]
    # @param type [String]
    # @param date [String]
    # @return [TrueClass, FalseClass]
    def type_date_filter(hit, type, date) # rubocop:disable Metrics/AbcSize
      if (type && hit["type"] != short_type(type)) || (date && hit["date"] != date)
        history = get_history hit, type, date
        return false unless history.any?

        hit["type"] = short_type type
        hit["datepub"] = history.first.at("td").text
        hit["link"] = history.first.at("a")[:href]
      end
      true
    end

    # @param hit [Hash]
    # @param type [String]
    # @param date [String]
    # @return [Array<Nokogiri::XML::Element>, Nokogiri::HTML::NodeSet]
    def get_history(hit, type, date)
      resp = Net::HTTP.get URI.parse(HitCollection::DOMAIN + hit["history"])
      history_doc = Nokogiri::HTML resp
      history = history_doc.xpath(
        "//table//a[contains(.,'#{long_type(type)}')]/../..",
      )
      return filter_history_by_date(history, history_doc, type, date) if date

      history
    end

    # @param history [Nokogiri::XML::NodeSet]
    # @param history_doc [Nokogiri::HTML::NodeSet]
    # @param type [String]
    # @param date [String]
    # @return [Array<Nokogiri::XML::Element>, Nokogiri::HTML::NodeSet]
    def filter_history_by_date(history, history_doc, type, date)
      if type
        history.select do |h|
          h.at("td[@class='table_datecol']").text == date
        end
      else
        history_doc.xpath(
          "//table//td[@class='table_datecol'][.='#{date}']/..",
        )
      end
    end

    #
    # Convetr long type name to short
    #
    # @param type [String]
    # @return [String]
    def short_type(type)
      tp = TYPES.select { |_, v| v == type }.keys
      tp.first || type
    end

    #
    # Convert shot type name to long
    #
    # @param [String]
    # @return [String]
    def long_type(type)
      TYPES[type] || type
    end

    #
    # Fetches YAML data
    #
    # @return [Hash]
    def data
      FileUtils.mkdir_p DATADIR
      ctime = File.ctime DATAFILE if File.exist? DATAFILE
      fetch_data if !ctime || ctime.to_date < Date.today
      @data ||= YAML.safe_load File.read(DATAFILE, encoding: "UTF-8")
    end

    #
    # fetch data form server and save it to file.
    #
    def fetch_data
      resp = Net::HTTP.get_response URI.parse("#{DOMAIN}/TR/")
      # return if there aren't any changes since last fetching
      return unless resp.code == "200"

      doc = Nokogiri::HTML resp.body
      @data = doc.xpath("//ul[@id='container']/li").map do |h_el|
        link = h_el.at("h2/a")
        pubdetails = h_el.at("p[@class='pubdetails']")
        fetch_hit h_el, link, pubdetails
      end
      File.write DATAFILE, @data.to_yaml, encoding: "UTF-8"
    end

    # @param h_el [Nokogiri::XML::Element]
    # @param link [Nokogiri::XML::Element]
    # @param pubdetails [Nokogiri::XML::Element]
    def fetch_hit(h_el, link, pubdetails) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      datepub = pubdetails.at("text()").text.match(/\d{4}-\d{2}-\d{2}/).to_s
      editor = h_el.xpath("ul[@class='editorlist']/li").map { |e| e.text.strip }
      keyword = h_el.xpath("ul[@class='taglist']/li").map { |e| e.text.strip }
      {
        "title" => link.text.gsub("\u00a0", " "),
        "link" => link[:href],
        "type" => h_el.at("div").text.upcase,
        "workgroup" => h_el.xpath("p[@class='deliverer']").map(&:text),
        "datepub" => datepub,
        "history" => pubdetails.at("a[text()='History']")[:href],
        "editor" => editor,
        "keyword" => keyword,
      }
    end
  end
end

# frozen_string_literal: true

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
      "WD" => "Working Draft"
    }.freeze
    DOMAIN = "https://www.w3.org".freeze
    DATADIR = File.expand_path(".relaton/w3c", Dir.home).freeze
    DATAFILE = File.expand_path("bibliograhy.yml", DATADIR).freeze

    # @param ref [String] reference to search
    def initialize(ref)
      %r{
        ^(W3C\s)?
        (?<type>(CR|NOTE|PER|PR|REC|RET|WD|Candidate\sRecommendation|
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
    def from_yaml(title_date, type)
      /(?<title>.+)\s(?<date>\d{4}-\d{2}-\d{2})$/ =~ title_date
      title ||= title_date
      result = data.select do |hit|
        hit["title"] == title && type_date_filter(hit, type, date)
      end
      result.map { |h| Hit.new(h, self) }
    end

    def type_date_filter(hit, type, date)
      history = []
      history_doc = nil
      if type && hit["type"] != short_type(type) || date && hit["date"] != date
        history_doc = get_history hit
        if type
          history = history_doc.xpath("//table//a[contains(.,'#{long_type(type)}')]/../..")
        end
        if date
          if type
            history = history.select { |h| h.at("td[@class='table_datecol']").text == date }
          else
            history = history_doc.xpath("//table//td[@class='table_datecol'][.='#{date}']/..")
          end
        end
        return false unless history.any?

        hit["type"] = short_type type
        hit["datepub"] = history.first.at("td").text
        hit["link"] = history.first.at("a")[:href]
      end
      true
    end

    def get_history(hit)
      resp = Net::HTTP.get URI.parse(HitCollection::DOMAIN + hit["history"])
      Nokogiri::HTML resp
    end

    #
    # Convetr long type name to short
    #
    # @param type [String]
    # @return [String]
    def short_type(type)
      tp = TYPES.select { |k,v| v == type }.keys
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
      resp = Net::HTTP.get_response URI.parse(DOMAIN + "/TR/")
      # return if there aren't any changes since last fetching
      return unless resp.code == "200"

      doc = Nokogiri::HTML resp.body
      @data = doc.xpath("//ul[@id='container']/li").map do |s|
        link = s.at("h2/a")
        pubdetails = s.at("p[@class='pubdetails']")
        {
          "title" => link.text.gsub("\u00a0", " "),
          "link" => link[:href],
          "type" => s.at("div").text.upcase,
          "workgroup" => s.xpath("p[@class='deliverer']").map(&:text),
          "datepub" => pubdetails.at("text()").text.match(/\d{4}-\d{2}-\d{2}/).to_s,
          "history" => pubdetails.at("a[text()='History']")[:href],
          "editor" => s.xpath("ul[@class='editorlist']/li").map { |e| e.text.strip },
          "keyword" => s.xpath("ul[@class='taglist']/li").map { |e| e.text.strip }
        }
      end
      File.write DATAFILE, @data.to_yaml, encoding: "UTF-8"
    end
  end
end

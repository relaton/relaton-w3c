RSpec.describe RelatonW3c::DataParser do
  it "create instance and run parsing" do
    parser = double "parser"
    expect(parser).to receive(:parse)
    expect(RelatonW3c::DataParser).to receive(:new).with(:sol, :fetcher).and_return(parser)
    RelatonW3c::DataParser.parse :sol, :fetcher
  end

  it "initialize parser" do
    subj = RelatonW3c::DataParser.new :sol, :fetcher
    expect(subj.instance_variable_get(:@sol)).to eq :sol
    expect(subj.instance_variable_get(:@fetcher)).to eq :fetcher
  end

  context "instance" do
    subject do
      rdf = RDF::Repository.load "spec/fixtures/tr.rdf"
      expect(RDF::Repository).to receive(:load).with("http://www.w3.org/2002/01/tr-automation/tr.rdf").and_return(rdf)
      fetcher = RelatonW3c::DataFetcher.new "dir", "bibxml"
      sol = fetcher.query.filter(link: "https://www.w3.org/TR/1998/REC-CSS2-19980512/fonts.html").first
      RelatonW3c::DataParser.new sol, fetcher
    end

    it "skip parsing doc" do
      expect(subject).to receive(:type).and_return "not_allowed_type"
      expect(subject).not_to receive(:parse_doctype)
      expect(subject.parse).to be_nil
    end

    it "parse doc" do
      expect(subject).to receive(:parse_doctype)
      expect(subject).to receive(:parse_title)
      expect(subject).to receive(:parse_link)
      expect(subject).to receive(:parse_docid)
      expect(subject).to receive(:identifier).with(kind_of(String))
      expect(subject).to receive(:parse_series)
      expect(subject).to receive(:parse_date)
      expect(subject).to receive(:parse_relation)
      expect(subject).to receive(:parse_contrib)
      expect(subject).to receive(:parse_editorialgroup)
      expect(RelatonBib::BibliographicItem).to receive(:new).and_return :bib
      expect(subject.parse).to eq :bib
    end

    it "parse title" do
      title = subject.parse_title
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title.first).to be_instance_of RelatonBib::TypedTitleString
      expect(title.first.title).to eq "CSS3 module: Web Fonts"
    end

    it "parse link" do
      link = subject.parse_link
      expect(link).to be_instance_of Array
      expect(link.first).to be_instance_of RelatonBib::TypedUri
      expect(link.first.type).to eq "src"
      expect(link.first.content.to_s).to eq "https://www.w3.org/TR/1998/REC-CSS2-19980512/fonts.html"
    end

    it "parse docid" do
      docid = subject.parse_docid
      expect(docid).to be_instance_of Array
      expect(docid.first).to be_instance_of RelatonBib::DocumentIdentifier
      expect(docid.first.type).to eq "W3C"
      expect(docid.first.id).to eq "W3C REC-CSS2-19980512/fonts"
    end

    # it "parse identifier" do
    #   expect(subject.identifier("https://www.w3.org/TR/1998/REC-CSS2-19980512/fonts.html")).to eq "REC-CSS2-19980512/fonts"
    # end

    it "parse series" do
      series = subject.parse_series
      expect(series).to be_instance_of Array
      expect(series.size).to eq 1
      expect(series.first).to be_instance_of RelatonBib::Series
      expect(series.first.title.title.content).to eq "W3C REC"
      expect(series.first.number).to eq "REC-CSS2-19980512/fonts"
    end

    it "parse doctype" do
      expect(subject.parse_doctype).to eq "recommendation"
    end

    it "parse date" do
      date = subject.parse_date
      expect(date).to be_instance_of Array
      expect(date.size).to eq 1
      expect(date.first).to be_instance_of RelatonBib::BibliographicDate
    end

    it "parse relation" do
      relation = subject.parse_relation
      expect(relation).to be_instance_of Array
      expect(relation.size).to eq 1
      expect(relation.first).to be_instance_of RelatonBib::DocumentRelation
      expect(relation.first.type).to eq "obsoletes"
      expect(relation.first.bibitem.formattedref.content).to eq "W3C PR-DSig-label-19980403"
    end

    it "parse contrib" do
      contrib = subject.parse_contrib
      expect(contrib).to be_instance_of Array
      expect(contrib.size).to eq 2
      expect(contrib.first).to be_instance_of RelatonBib::ContributionInfo
      expect(contrib.first.role[0].type).to eq "editor"
      expect(contrib.first.entity.name.completename.content).to eq "Philip DesAutels"
    end

    it "parse editorialgroup" do
      editorialgroup = subject.parse_editorialgroup
      expect(editorialgroup).to be_instance_of RelatonBib::EditorialGroup
      expect(editorialgroup.technical_committee.size).to eq 1
      expect(editorialgroup.technical_committee.first.workgroup.name)
        .to eq "Web Hypertext Application Technology Working Group"
    end

    it "warn if working goroup name not found" do
      fetcher = subject.instance_variable_get :@fetcher
      expect(fetcher).to receive(:group_names).and_return Hash.new
      expect do
        subject.parse_editorialgroup
      end.to output(/Working group name not found for/).to_stderr
    end
  end
end

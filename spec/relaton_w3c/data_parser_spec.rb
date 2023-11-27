RSpec.describe RelatonW3c::DataParser do
  let(:rdf) { RDF::Repository.load "spec/fixtures/tr.rdf" }
  let(:fetcher) { RelatonW3c::DataFetcher.new "dir", "bibxml" }

  it "create instance and run parsing" do
    parser = double "parser"
    expect(parser).to receive(:parse)
    expect(RelatonW3c::DataParser).to receive(:new).with(:rdf, :sol, :fetcher).and_return(parser)
    RelatonW3c::DataParser.parse :rdf, :sol, :fetcher
  end

  it "initialize parser" do
    subj = RelatonW3c::DataParser.new :rdf, :sol, :fetcher
    expect(subj.instance_variable_get(:@rdf)).to eq :rdf
    expect(subj.instance_variable_get(:@sol)).to eq :sol
    expect(subj.instance_variable_get(:@fetcher)).to eq :fetcher
  end

  context "instance versioned" do
    let(:solution) do
      fetcher.query_versioned_docs(rdf).filter(link: "https://www.w3.org/TR/1998/REC-CSS2-19980512/fonts.html").first
    end

    subject { RelatonW3c::DataParser.new rdf, solution, fetcher }

    it "skip parsing doc" do
      expect(subject).to receive(:types_stages).and_return ["not_allowed_type"]
      expect(subject).not_to receive(:parse_doctype)
      expect(subject.parse).to be_nil
    end

    it "parse doc" do
      expect(subject).to receive(:parse_docstatus).and_return :status
      expect(subject).to receive(:parse_doctype).and_return :doctype
      expect(subject).to receive(:parse_title).and_return :title
      expect(subject).to receive(:parse_link).and_return :link
      expect(subject).to receive(:parse_docid).and_return :docid
      expect(subject).to receive(:parse_formattedref).and_return :formattedref
      expect(subject).to receive(:identifier).with(no_args).and_return :docnumber
      expect(subject).to receive(:parse_series).and_return :series
      expect(subject).to receive(:parse_date).and_return :date
      expect(subject).to receive(:parse_relation).and_return :relation
      expect(subject).to receive(:parse_contrib).and_return :contributor
      expect(subject).to receive(:parse_editorialgroup).and_return :editorialgroup
      expect(RelatonBib::BibliographicItem).to receive(:new).with(
        docstatus: :status, doctype: :doctype, language: ["en"], script: ["Latn"],
        type: "standard", title: :title, link: :link, docid: :docid, formattedref: :formattedref,
        contributor: :contributor, docnumber: :docnumber, series: :series, date: :date, relation: :relation,
        editorialgroup: :editorialgroup
      ).and_return :bib
      expect(subject.parse).to eq :bib
    end

    it "parse doc status" do
      status = subject.parse_docstatus
      expect(status).to be_a RelatonBib::DocumentStatus
    end

    it "parse title" do
      title = subject.parse_title
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title.first).to be_instance_of RelatonBib::TypedTitleString
      expect(title.first.title.content).to eq "CSS3 module: Web Fonts"
    end

    context "unvesioned doc" do
      let(:solution) do
        fetcher.query_unversioned_docs(rdf).detect { |sol| sol.version_of == "https://www.w3.org/TR/WD-font/" }
      end

      it "parse title" do
        title = subject.parse_title
        expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
        expect(title.first).to be_instance_of RelatonBib::TypedTitleString
        expect(title.first.title.content).to eq "Web Fonts"
      end
    end

    it "parse link" do
      link = subject.parse_link
      expect(link).to be_instance_of Array
      expect(link.size).to eq 2
      link.each { |l| expect(l).to be_instance_of RelatonBib::TypedUri }
      expect(link.first.type).to eq "src"
      expect(link.first.content.to_s).to eq "https://www.w3.org/TR/1998/REC-CSS2-19980512/fonts.html"
      expect(link[1].type).to eq "current"
      expect(link[1].content.to_s).to eq "https://drafts.csswg.org/css-fonts-3/"
    end

    it "parse docid" do
      docid = subject.parse_docid
      expect(docid).to be_instance_of Array
      expect(docid.first).to be_instance_of RelatonBib::DocumentIdentifier
      expect(docid.first.type).to eq "W3C"
      expect(docid.first.id).to eq "W3C REC-CSS2-19980512/fonts"
    end

    it "parse identifier" do
      expect(subject.identifier("https://www.w3.org/TR/1998/CSS2")).to eq "CSS2"
    end

    it "parse series" do
      series = subject.parse_series
      expect(series).to be_instance_of Array
      expect(series.size).to eq 1
      expect(series.first).to be_instance_of RelatonBib::Series
      expect(series.first.title.title.content).to eq "W3C REC"
      expect(series.first.number).to eq "REC-CSS2-19980512/fonts"
    end

    it "parse doctype" do
      doctype = subject.parse_doctype
      expect(doctype).to be_instance_of RelatonW3c::DocumentType
      expect(doctype.type).to eq "technicalReport"
    end

    it "parse date" do
      date = subject.parse_date
      expect(date).to be_instance_of Array
      expect(date.size).to eq 1
      expect(date.first).to be_instance_of RelatonBib::BibliographicDate
    end

    context "parse relation" do
      it "obsoletes & hasDraft" do
        relation = subject.parse_relation
        expect(relation).to be_instance_of Array
        expect(relation.size).to eq 1
        expect(relation.first).to be_instance_of RelatonBib::DocumentRelation
        expect(relation.first.type).to eq "obsoletes"
        expect(relation.first.bibitem.formattedref.content).to eq "W3C PR-DSig-label-19980403"
      end

      it "instance (version)" do
        sol = double "sol", version_of: "CSS2"
        data = double "data"
        rel = double "rel", link: "https://www.w3.org/TR/1998/REC-CSS2-19980512"
        expect(data).to receive(:query).with(kind_of(SPARQL::Algebra::Operator::Prefix)).and_return [rel]
        fetcher = double "fetcher", data: data
        parser = RelatonW3c::DataParser.new data, sol, fetcher
        relation = parser.parse_relation
        expect(relation).to be_instance_of Array
        expect(relation.size).to eq 1
        expect(relation.first).to be_instance_of RelatonBib::DocumentRelation
        expect(relation.first.type).to eq "hasEdition"
        expect(relation.first.bibitem.formattedref.content).to eq "W3C REC-CSS2-19980512"
      end
    end

    it "parse formattedref" do
      sol = double "sol", version_of: "CSS2"
      parser = RelatonW3c::DataParser.new rdf, sol, nil
      fref = parser.parse_formattedref
      expect(fref).to be_instance_of RelatonBib::FormattedRef
      expect(fref.content).to eq "W3C CSS2"
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

    it "#version_of" do
      vo = subject.version_of
      expect(vo).to be_instance_of RDF::Query::Solutions
      expect(vo.size).to eq 1
    end
  end

  context "instance unversioned" do
    let(:solution) do
      fetcher.query_unversioned_docs(rdf).detect { |s| s.version_of.to_s == "https://www.w3.org/TR/css3-fonts/" }
    end

    subject { RelatonW3c::DataParser.new rdf, solution, fetcher }

    it "#types_stages" do
      ts = subject.types_stages
      expect(ts).to eq ["REC", "Retired"]
    end
  end
end

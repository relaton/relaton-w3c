RSpec.describe RelatonW3c::DataFetcher do
  # it do
  #   VCR.use_cassette "rdf" do
  #     RelatonW3c::DataFetcher.fetch
  #   end
  # end

  it "create output dir and run fetcher" do
    expect(Dir).to receive(:exist?).with("dir").and_return(false)
    expect(FileUtils).to receive(:mkdir_p).with("dir")
    fetcher = double("fetcher")
    expect(fetcher).to receive(:fetch)
    expect(RelatonW3c::DataFetcher)
      .to receive(:new).with("dir", "xml").and_return(fetcher)
    RelatonW3c::DataFetcher.fetch output: "dir", format: "xml"
  end

  context "instance" do
    subject { RelatonW3c::DataFetcher.new("dir", "bibxml") }

    before do
      rdf = RDF::Repository.load "spec/fixtures/tr.rdf"
      expect(RDF::Repository).to receive(:load).with("http://www.w3.org/2002/01/tr-automation/tr.rdf").and_return(rdf)
    end

    it "initialize fetcher" do
      expect(subject.instance_variable_get(:@ext)).to eq "xml"
      expect(subject.instance_variable_get(:@files)).to eq []
      expect(subject.instance_variable_get(:@group_names))
        .to be_instance_of(Hash)
      expect(subject.instance_variable_get(:@data))
        .to be_instance_of(RDF::Repository)
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "bibxml"
      expect(subject).to be_instance_of(RelatonW3c::DataFetcher)
    end

    it "fetch data" do
      expect(subject).to receive(:save_doc).with(:bib).exactly(33).times
      expect(RelatonBib::BibXMLParser).to receive(:parse).with(kind_of(String))
        .and_return(:bib).exactly(25).times
      expect(RelatonW3c::DataParser).to receive(:parse)
        .with(kind_of(RDF::Query::Solution), subject)
        .and_return(:bib).exactly(8).times
      subject.fetch
    end

    context "save doc" do
      it "skip" do
        expect(subject).not_to receive(:file_name)
        subject.save_doc nil
      end

      it "bibxml" do
        bib = double("bib", docnumber: "bib")
        expect(bib).to receive(:to_bibxml).and_return("<xml/>")
        expect(File).to receive(:write)
          .with("dir/BIB.xml", "<xml/>", encoding: "UTF-8")
        subject.save_doc bib
      end

      it "xml" do
        subject.instance_variable_set(:@format, "xml")
        bib = double("bib", docnumber: "bib")
        expect(bib).to receive(:to_xml).with(bibdata: true).and_return("<xml/>")
        expect(File).to receive(:write)
          .with("dir/BIB.xml", "<xml/>", encoding: "UTF-8")
        subject.save_doc bib
      end

      it "yaml" do
        subject.instance_variable_set(:@format, "yaml")
        subject.instance_variable_set(:@ext, "yaml")
        bib = double("bib", docnumber: "bib")
        expect(bib).to receive(:to_hash).and_return({ id: 123 })
        expect(File).to receive(:write)
          .with("dir/BIB.yaml", /id: 123/, encoding: "UTF-8")
        subject.save_doc bib
      end

      it "warn when file exists" do
        subject.instance_variable_set(:@files, ["dir/BIB.xml"])
        bib = double("bib", docnumber: "bib")
        expect(bib).to receive(:to_bibxml).and_return("<xml/>")
        expect(File).to receive(:write)
          .with("dir/BIB.xml", "<xml/>", encoding: "UTF-8")
        expect { subject.save_doc bib }
          .to output(/File dir\/BIB.xml already exists/).to_stderr
      end
    end
  end
end

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
    let(:index) { double("index") }

    before do
      rdf = RDF::Repository.load "spec/fixtures/tr.rdf"
      expect(RDF::Repository).to receive(:load).with("http://www.w3.org/2002/01/tr-automation/tr.rdf").and_return(rdf)
      expect(RelatonW3c::DataIndex).to receive(:new).and_return(index)
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
      expect(subject.instance_variable_get(:@index)).to eq index
    end

    it "fetch data" do
      expect(subject).to receive(:save_doc).with(:bib).exactly(16).times
      expect(subject).to receive(:save_doc).with(:bib, warn_duplicate: false).exactly(25).times
      expect(RelatonW3c::BibXMLParser).to receive(:parse).with(kind_of(String))
        .and_return(:bib).exactly(25).times
      expect(RelatonW3c::DataParser).to receive(:parse)
        .with(kind_of(RDF::Query::Solution), subject)
        .and_return(:bib).exactly(16).times
      expect(index).to receive(:sort!).and_return(index)
      expect(index).to receive(:save)
      subject.fetch
    end

    context "save doc" do
      let(:bib) { double("bib", docnumber: "bib") }

      it "skip" do
        expect(subject).not_to receive(:file_name)
        subject.save_doc nil
      end

      it "bibxml" do
        expect(bib).to receive(:to_bibxml).and_return("<xml/>")
        expect(File).to receive(:write)
          .with("dir/bib.xml", "<xml/>", encoding: "UTF-8")
        expect(index).to receive(:add).with("bib", "dir/bib.xml")
        subject.save_doc bib
      end

      it "xml" do
        subject.instance_variable_set(:@format, "xml")
        expect(bib).to receive(:to_xml).with(bibdata: true).and_return("<xml/>")
        expect(File).to receive(:write)
          .with("dir/bib.xml", "<xml/>", encoding: "UTF-8")
        expect(index).to receive(:add).with("bib", "dir/bib.xml")
        subject.save_doc bib
      end

      it "yaml" do
        subject.instance_variable_set(:@format, "yaml")
        subject.instance_variable_set(:@ext, "yaml")
        expect(bib).to receive(:to_hash).and_return({ id: 123 })
        expect(File).to receive(:write)
          .with("dir/bib.yaml", /id: 123/, encoding: "UTF-8")
        expect(index).to receive(:add).with("bib", "dir/bib.yaml")
        subject.save_doc bib
      end

      context "when file exists" do
        before do
          subject.instance_variable_set(:@files, ["dir/bib.xml"])
          expect(bib).to receive(:to_bibxml).and_return("<xml/>")
        end

        it "warn" do
          expect do
            subject.save_doc bib
          end.to output(/File dir\/bib.xml already exists/).to_stderr
        end

        it "do not warn if file exist" do
          expect do
            subject.save_doc bib, warn_duplicate: false
          end.not_to output.to_stderr
        end
      end
    end
  end
end

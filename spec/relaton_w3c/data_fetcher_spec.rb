RSpec.describe RelatonW3c::DataFetcher do
  # it do
  #   VCR.use_cassette "rdf" do
  #     RelatonW3c::DataFetcher.fetch
  #   end
  # end

  it "create output dir and run fetcher" do
    expect(FileUtils).to receive(:mkdir_p).with("dir")
    fetcher = double("fetcher")
    expect(fetcher).to receive(:fetch)
    expect(RelatonW3c::DataFetcher)
      .to receive(:new).with("dir", "xml").and_return(fetcher)
    RelatonW3c::DataFetcher.fetch "w3c-rdf", output: "dir", format: "xml"
  end

  context "instance" do
    subject { RelatonW3c::DataFetcher.new("dir", "bibxml") }
    let(:index) { double("index") }

    before do
      expect(RelatonW3c::DataIndex).to receive(:create_from_file).and_return(index)
    end

    it "initialize fetcher" do
      expect(subject.instance_variable_get(:@ext)).to eq "xml"
      expect(subject.instance_variable_get(:@group_names))
        .to be_instance_of(Hash)
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "bibxml"
      expect(subject).to be_instance_of(RelatonW3c::DataFetcher)
      expect(subject.instance_variable_get(:@index)).to eq index
    end

    context "fetch data" do
      before do
        expect(index).to receive(:sort!).and_return(index)
        expect(index).to receive(:save)
      end

      context do
        let(:rdf) { RDF::Repository.load "spec/fixtures/tr.rdf" }

        before do
          expect(subject).to receive(:save_doc).with(:bib).exactly(16).times
          expect(RelatonW3c::DataParser).to receive(:parse)
            .with(rdf, kind_of(RDF::Query::Solution), subject)
            .and_return(:bib).exactly(16).times
        end

        it "w3c-rdf" do
          expect(RDF::Repository).to receive(:load).with("http://www.w3.org/2002/01/tr-automation/tr.rdf").and_return(rdf)
          expect(subject).to receive(:add_has_edition_relation).with(:bib).exactly(8).times
          # expect(subject).to receive(:save_doc).with(:bib, warn_duplicate: false).exactly(25).times
          # expect(RelatonW3c::BibXMLParser).to receive(:parse).with(kind_of(String))
          #   .and_return(:bib).exactly(25).times
          subject.fetch "w3c-rdf"
        end

        it "w3c-tr-archive" do
          expect(Dir).to receive(:[]).with("w3c-tr-archive/*.rdf").and_return [:file]
          expect(RDF::Repository).to receive(:load).with(:file).and_return(rdf)
          expect(subject).to receive(:add_has_edition_relation).with(:bib).exactly(8).times
          subject.fetch "w3c-tr-archive"
        end
      end

      it "warn if error is raised" do
        rdf = double("rdf")
        sol1 = double("sol1", link: "http://w3.org/doc1")
        sol2 = double("sol2", version_of: "http://w3.org/doc2")
        expect(rdf).to receive(:query).and_return [sol1], [sol2]
        expect(RelatonW3c::DataParser).to receive(:parse).with(rdf, sol1, subject).and_raise StandardError
        expect(RelatonW3c::DataParser).to receive(:parse).with(rdf, sol2, subject).and_raise StandardError
        expect(Dir).to receive(:[]).with("w3c-tr-archive/*.rdf").and_return [:file]
        expect(RDF::Repository).to receive(:load).with(:file).and_return rdf
        expect { subject.fetch "w3c-tr-archive" }.to output(
          /Error: document http:\/\/w3.org\/doc1 StandardError/,
        ).to_stderr
      end
    end

    # context "parse static dataset" do
    #   it "warn if error is raised" do
    #     expect(Dir).to receive(:[]).with(/data\/*/).and_return [:file]
    #     expect(File).to receive(:read).with(:file, encoding: "UTF-8").and_raise StandardError
    #     expect do
    #       subject.parse_static_dataset
    #     end.to output(/Error: document file StandardError/).to_stderr
    #   end
    # end

    context "save doc" do
      let(:bib) { double("bib", docnumber: "bib") }

      before { subject.instance_variable_set(:@files, []) }

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

    context "add has edition relation" do
      context "previous parsed file exists" do
        it "BibXML" do
          expect(subject).to receive(:file_name).and_return("bib.xml")
          expect(File).to receive(:exist?).with("bib.xml").and_return(true)
          expect(File).to receive(:read).with("bib.xml", encoding: "UTF-8").and_return(:bibxml)
          prev_docid = double("id1", id: "rel-20110111")
          prev_rel_bib = double("prev_rel_bib", docidentifier: [prev_docid], id: "rel-20110111")
          prev_rel = double("prev_rel", bibitem: prev_rel_bib, type: "hasEdition")
          prev_bib = double("prev_bib", relation: [prev_rel])
          expect(RelatonW3c::BibXMLParser).to receive(:parse).with(:bibxml).and_return(prev_bib)
          docid = double("id2", id: "rel-20121122")
          rel_bib = double("rel_bib", docidentifier: [docid], id: "rel-20121122")
          rel = double("rel", bibitem: rel_bib, type: "hasEdition")
          expect(rel).to receive(:type=).with("instance")
          bib = double("bib", relation: [rel], docnumber: "bib")
          subject.add_has_edition_relation bib
          expect(bib.relation).to eq [rel, prev_rel]
        end

        it "XML" do
          subject.instance_variable_set(:@format, "xml")
          expect(subject).to receive(:file_name).and_return("bib.xml")
          expect(File).to receive(:exist?).with("bib.xml").and_return(true)
          expect(File).to receive(:read).with("bib.xml", encoding: "UTF-8").and_return(:xml)
          prev_bib = double("prev_bib", relation: [])
          expect(RelatonW3c::XMLParser).to receive(:from_xml).with(:xml).and_return(prev_bib)
          bib = double("bib", relation: [], docnumber: "bib")
          subject.add_has_edition_relation bib
          expect(bib.relation).to eq []
        end

        it "YAML" do
          subject.instance_variable_set(:@format, "yaml")
          expect(subject).to receive(:file_name).and_return("bib.yaml")
          expect(File).to receive(:exist?).with("bib.yaml").and_return(true)
          expect(YAML).to receive(:load_file).with("bib.yaml").and_return(:hash)
          prev_bib = double("prev_bib", relation: [])
          expect(RelatonW3c::W3cBibliographicItem).to receive(:from_hash).with(:hash).and_return(prev_bib)
          bib = double("bib", relation: [], docnumber: "bib")
          subject.add_has_edition_relation bib
          expect(bib.relation).to eq []
        end
      end
    end
  end
end

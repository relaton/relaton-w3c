RSpec.describe RelatonW3c::DataFetcher do
  # it do
  #   VCR.use_cassette "rdf" do
  #     RelatonW3c::DataFetcher.fetch
  #   end
  # end

  it "create output dir and run fetcher" do
    expect(FileUtils).to receive(:mkdir_p).with("dir")
    fetcher = double("fetcher")
    expect(fetcher).to receive(:fetch).with(no_args)
    expect(RelatonW3c::DataFetcher).to receive(:new).with("dir", "xml", fetch_versions: true).and_return(fetcher)
    RelatonW3c::DataFetcher.fetch output: "dir", format: "xml"
  end

  context "instance" do
    subject { RelatonW3c::DataFetcher.new("dir", "bibxml") }
    let(:index) { double("index") }
    let(:index1) { double("index1") }

    before do
      expect(RelatonW3c::DataIndex).to receive(:create_from_file).and_return(index)
      expect(Relaton::Index).to receive(:find_or_create).with(:W3C, file: "index1.yaml").and_return(index1)
    end

    it "initialize fetcher" do
      expect(subject.instance_variable_get(:@ext)).to eq "xml"
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "bibxml"
      expect(subject).to be_instance_of(RelatonW3c::DataFetcher)
      expect(subject.instance_variable_get(:@index)).to eq index
      expect(subject.instance_variable_get(:@index1)).to eq index1
    end

    context "fetch data" do
      before do
        expect(index).to receive(:sort!).and_return(index)
        expect(index).to receive(:save)
        expect(index1).to receive(:save)
      end

      it "success", vcr: "fetch-data" do
        allow(subject.client).to receive(:specifications).and_wrap_original do |method|
          specs = method.call items: 2
          expect(specs).to receive(:next).and_wrap_original do |next_method|
            specs_page2 = next_method.call
            expect(specs_page2).to receive(:next?).and_return(false)
            specs_page2
          end
          specs
        end
        expect(subject).to receive(:save_doc).with(kind_of(RelatonW3c::W3cBibliographicItem)).exactly(4).times
        subject.fetch
      end
    end

    context "save doc" do
      let(:bib) { double("bib", docnumber: "bib") }

      it "skip" do
        expect(subject).not_to receive(:file_name)
        subject.save_doc nil
      end

      context do
        before do
          expect(index).to receive(:add).with(kind_of(RelatonW3c::PubId), "dir/bib.xml")
          expect(index1).to receive(:add_or_update).with(kind_of(Hash), "dir/bib.xml")
        end

        it "bibxml" do
          expect(bib).to receive(:to_bibxml).and_return("<xml/>")
          expect(File).to receive(:write).with("dir/bib.xml", "<xml/>", encoding: "UTF-8")
          subject.save_doc bib
        end

        it "xml" do
          subject.instance_variable_set(:@format, "xml")
          expect(bib).to receive(:to_xml).with(bibdata: true).and_return("<xml/>")
          expect(File).to receive(:write).with("dir/bib.xml", "<xml/>", encoding: "UTF-8")
          subject.save_doc bib
        end
      end

      it "yaml" do
        subject.instance_variable_set(:@format, "yaml")
        subject.instance_variable_set(:@ext, "yaml")
        expect(bib).to receive(:to_hash).and_return({ id: 123 })
        expect(File).to receive(:write).with("dir/bib.yaml", /id: 123/, encoding: "UTF-8")
        expect(index).to receive(:add).with(kind_of(RelatonW3c::PubId), "dir/bib.yaml")
        expect(index1).to receive(:add_or_update).with(kind_of(Hash), "dir/bib.yaml")
        subject.save_doc bib
      end

      context "when file exists" do
        before do
          subject.instance_variable_get(:@files) << "dir/bib.xml"
          expect(bib).to receive(:to_bibxml).and_return("<xml/>")
          expect(File).to receive(:write).with("dir/bib.xml", "<xml/>", encoding: "UTF-8")
        end

        it "warn" do
          expect do
            subject.save_doc bib
          end.to output(/File dir\/bib.xml already exists/).to_stderr_from_any_process
        end

        it "do not warn if file exist" do
          expect do
            subject.save_doc bib, warn_duplicate: false
          end.not_to output.to_stderr_from_any_process
        end
      end
    end
  end
end

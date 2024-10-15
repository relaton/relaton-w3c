require "jing"

RSpec.describe RelatonW3c do
  before { RelatonW3c.instance_variable_set :@configuration, nil }

  it "has a version number" do
    expect(RelatonW3c::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = RelatonW3c.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  context "get document" do
    before do
      allow_any_instance_of(Relaton::Index::Type).to receive(:actual?).and_return(false)
      allow_any_instance_of(Relaton::Index::FileIO).to receive(:check_file).and_return(nil)
    end

    it "by title only", vcr: "cr_json_ld11" do
      expect do
        doc = RelatonW3c::W3cBibliography.get "W3C REC-json-ld11-20200716"
        expect(doc).to be_instance_of RelatonW3c::W3cBibliographicItem
        file = "spec/fixtures/cr_json_ld11.xml"
        xml = doc.to_xml(bibdata: true)
        File.write file, xml, encoding: "UTF-8" unless File.exist? file
        expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
          .sub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        schema = Jing.new "grammars/relaton-w3c-compile.rng"
        errors = schema.validate file
        expect(errors).to eq []
      end.to output(
        include("[relaton-w3c] INFO: (W3C REC-json-ld11-20200716) Fetching from Relaton repository ...",
                "[relaton-w3c] INFO: (W3C REC-json-ld11-20200716) Found: `W3C REC-json-ld11-20200716`"),
      ).to_stderr_from_any_process
    end

    it "dated" do
      VCR.use_cassette "rec_xml_names_20091208" do
        doc = RelatonW3c::W3cBibliography.get "W3C REC-xml-names-20091208"
        expect(doc.title.first.title.content).to eq(
          "Namespaces in XML 1.0 (Third Edition)",
        )
      end
    end

    it "undated", vcr: "rec_xml_names" do
      doc = RelatonW3c::W3cBibliography.get "W3C xml-names"
      file = "spec/fixtures/rec_xml_names.xml"
      xml = doc.to_xml(bibdata: true)
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      schema = Jing.new "grammars/relaton-w3c-compile.rng"
      errors = schema.validate file
      expect(errors).to eq []
    end

    context "latest version" do
      it "last year", vcr: "last_year" do
        doc = RelatonW3c::W3cBibliography.get "W3C css"
        expect(doc.docidentifier[0].id).to eq "W3C css-2023"
      end

      it "last date", vcr: "last_date" do
        doc = RelatonW3c::W3cBibliography.get "W3C NOTE-css-2018"
        expect(doc.docidentifier[0].id).to eq "W3C NOTE-css-2018-20190122"
      end
    end

    it "TR type" do
      VCR.use_cassette "w3c_tr_vocab-adms" do
        doc = RelatonW3c::W3cBibliography.get "W3C TR vocab-adms"
        expect(doc.docidentifier[0].id).to eq "W3C vocab-adms"
      end
    end

    it "by URL", vcr: "rec_xml_names" do
      doc = RelatonW3c::W3cBibliography.get "https://www.w3.org/TR/xml-names/"
      file = "spec/fixtures/xml_names.xml"
      xml = doc.to_xml(bibdata: true)
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
    end

    it "W3C xml" do
      VCR.use_cassette "w3c_xml" do
        doc = RelatonW3c::W3cBibliography.get "W3C xml"
        expect(doc.docidentifier[0].id).to eq "W3C xml"
      end
    end

    it "not found" do
      VCR.use_cassette "not_found" do
        expect do
          bib = RelatonW3c::W3cBibliography.get "W3C not-found"
          expect(bib).to be_nil
        end.to output(/\[relaton-w3c\] INFO: \(W3C not-found\) Not found\./).to_stderr_from_any_process
      end
    end
  end
end

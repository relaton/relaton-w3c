require "jing"

RSpec.describe RelatonW3c do
  it "has a version number" do
    expect(RelatonW3c::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = RelatonW3c.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  context "get document" do
    it "by title only" do
      VCR.use_cassette "cr_json_ld11" do
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
      end
    end

    it "dated" do
      VCR.use_cassette "rec_xml_names_20091208" do
        doc = RelatonW3c::W3cBibliography.get "W3C REC-xml-names-20091208"
        expect(doc.title.first.title.content).to eq(
          "Namespaces in XML 1.0 (Third Edition)",
        )
      end
    end

    it "undated" do
      VCR.use_cassette "rec_xml_names" do
        doc = RelatonW3c::W3cBibliography.get "W3C xml-names"
        file = "spec/fixtures/rec_xml_names.xml"
        xml = doc.to_xml(bibdata: true)
        File.write file, xml, encoding: "UTF-8" unless File.exist? file
        expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        # schema = Jing.new "grammars/relaton-w3c-compile.rng"
        # errors = schema.validate file
        # expect(errors).to eq []
      end
    end

    it "TR type" do
      VCR.use_cassette "w3c_tr_vocab-adms" do
        doc = RelatonW3c::W3cBibliography.get "W3C TR vocab-adms"
        expect(doc.docidentifier[0].id).to eq "W3C vocab-adms"
      end
    end

    it "by URL" do
      VCR.use_cassette "rec_xml_names" do
        doc = RelatonW3c::W3cBibliography.get "https://www.w3.org/TR/xml-names/"
        file = "spec/fixtures/xml_names.xml"
        xml = doc.to_xml(bibdata: true)
        File.write file, xml, encoding: "UTF-8" unless File.exist? file
        expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      end
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
        end.to output(/not found/).to_stderr
      end
    end
  end
end

# frozen_string_literal: true

describe Relaton::W3c::Bibliography do
  before do
    allow_any_instance_of(Relaton::Index::Type).to receive(:actual?).and_return(false)
    allow_any_instance_of(Relaton::Index::FileIO).to receive(:check_file).and_return(nil)
  end

  it "raise error" do
    expect(Relaton::Index).to receive(:find_or_create).and_raise SocketError
    expect { described_class.get("W3C REC-json-ld11-20200716") }
      .to raise_error Relaton::RequestError
  end

  it "get by title", vcr: "cr_json_ld11" do
    doc = described_class.get("W3C CR-json-ld11-20200316")
    expect(doc).to be_instance_of Relaton::W3c::ItemData
    xml = doc.to_xml(bibdata: true)
    file = "spec/fixtures/cr_json_ld11.xml"
    File.write(file, xml, encoding: "UTF-8") unless File.exist?(file)
    expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
      .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
  end

  context "dated" do
    it "fetch", vcr: "rec_xml_names_20091208" do
      doc = described_class.get("W3C REC-xml-names-20091208")
      expect(doc.title.first.content).to eq "Namespaces in XML 1.0 (Third Edition)"
    end
  end

  context "undated" do
    it "fetch", vcr: "rec_xml_names" do
      doc = described_class.get("W3C xml-names")
      xml = Relaton::W3c::Bibdata.to_xml(doc)
      expect(xml).to be_equivalent_to File.read("spec/fixtures/rec_xml_names.xml", encoding: "UTF-8")
        .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      schema = Jing.new "grammars/relaton-w3c-compile.rng"
      errors = schema.validate file_xml(xml)
      expect(errors).to eq []
    end
  end

  context "latest version" do
    it "last year", vcr: "last_year" do
      doc = described_class.get("W3C xml-names")
      expect(doc.docidentifier[0].content).to eq "W3C xml-names"
    end

    it "last date", vcr: "last_date" do
      doc = described_class.get("W3C xml-names")
      expect(doc.docidentifier[0].content).to eq "W3C xml-names"
    end
  end

  it "TR type", vcr: "w3c_tr_vocab-adms" do
    doc = described_class.get("W3C vocab-adms")
    expect(doc.docidentifier[0].content).to eq "W3C vocab-adms"
  end

  it "by URL", vcr: "rec_xml_names" do
    doc = described_class.get("https://www.w3.org/TR/xml-names/")
    xml = doc.to_xml(bibdata: true)
    file = "spec/fixtures/rec_xml_names.xml"
    File.write(file, xml, encoding: "UTF-8") unless File.exist?(file)
    expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
      .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
  end

  it "W3C xml", vcr: "w3c_xml" do
    doc = described_class.get("W3C xml")
    expect(doc.docidentifier[0].content).to eq "W3C xml"
  end

  it "not found" do
    expect { described_class.get("W3C NOT-FOUND") }
      .to output(/Not found/).to_stderr_from_any_process
  end

  private

  def file_xml(xml)
    f = Tempfile.new(["w3c", ".xml"])
    f.write xml
    f.close
    f.path
  end
end

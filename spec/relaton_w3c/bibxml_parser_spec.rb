RSpec.describe RelatonW3c::BibXMLParser do
  it "return PubID type" do
    expect(RelatonW3c::BibXMLParser.pubid_type("docidentifier")).to eq "W3C"
  end

  it "return document identifiers" do
    doc = Nokogiri::XML <<~XML
      <reference anchor="W3C.P3P" target="http://www.w3.org/TR/P3P-20010211">
      </reference>
    XML
    ref = doc.at "reference"
    ids = RelatonW3c::BibXMLParser.docids(ref, "ver")
    expect(ids.first.id).to eq "W3C P3P-20010211"
  end
end

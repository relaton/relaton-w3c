RSpec.describe RelatonW3c::BibXMLParser do
  it "return PubID type" do
    expect(RelatonW3c::BibXMLParser.pubid_type("docidentifier")).to eq "W3C"
  end
end

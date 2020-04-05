RSpec.describe RelatonW3c::XMLParser do
  it "parse XML" do
    xml = File.read "spec/fixtures/cr_json_ld11.xml", encoding: "UTF-8"
    item = RelatonW3c::XMLParser.from_xml xml
    expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
  end

  it "warn if XML doesn't have bibitem or bibdata element" do
    item = ""
    expect { item = RelatonW3c::XMLParser.from_xml "" }.
      to output(/can't find bibitem/).to_stderr
    expect(item).to be_nil
  end
end

RSpec.describe RelatonW3c::HashConverter do
  it "crate bibitem form hash" do
    file = "spec/fixtures/cr_json_ld11.yml"
    hash = YAML.safe_load File.read(file, encoding: "UTF-8")
    bib = RelatonW3c::HashConverter.hash_to_bib hash
    item = RelatonW3c::W3cBibliographicItem.new bib
    expect(item.to_hash).to eq hash
  end
end

RSpec.describe RelatonW3c::W3cBibliographicItem do
  it "invalid document type warning" do
    expect do
      RelatonW3c::W3cBibliographicItem.new doctype: "invalid_type"
    end.to output(/invalid document type/).to_stderr
  end
end

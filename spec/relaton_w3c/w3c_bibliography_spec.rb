RSpec.describe RelatonW3c::W3cBibliography do
  it "raise RequestError" do
    expect(Relaton::Index).to receive(:find_or_create).and_raise SocketError
    expect do
      RelatonW3c::W3cBibliography.search "ref"
    end.to raise_error RelatonBib::RequestError
  end
end

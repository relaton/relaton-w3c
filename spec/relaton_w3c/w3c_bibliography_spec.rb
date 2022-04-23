RSpec.describe RelatonW3c::W3cBibliography do
  it "raise RequestError" do
    uri = double "URI"
    expect(uri).to receive(:open).and_raise SocketError
    expect(URI).to receive(:parse).and_return uri
    expect do
      RelatonW3c::W3cBibliography.search "ref"
    end.to raise_error RelatonBib::RequestError
  end
end

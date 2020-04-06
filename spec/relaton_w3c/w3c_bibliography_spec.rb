RSpec.describe RelatonW3c::W3cBibliography do
  it "raise RequestError" do
    expect(File).to receive(:exist?).with(RelatonW3c::HitCollection::DATAFILE).
      and_return true

    ctime = double to_date: Date.today.prev_day
    expect(File).to receive(:ctime).with(RelatonW3c::HitCollection::DATAFILE).
      and_return ctime

    expect(Net::HTTP).to receive(:get_response).and_raise SocketError
    expect do
      RelatonW3c::W3cBibliography.search "ref"
    end.to raise_error RelatonBib::RequestError
  end
end

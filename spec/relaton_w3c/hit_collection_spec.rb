RSpec.describe RelatonW3c::HitCollection do
  it "fetch data" do
    expect(File).to receive(:exist?).and_call_original.at_least :once
    expect(File).to receive(:exist?).with(RelatonW3c::HitCollection::DATAFILE).
      and_return(true).at_most(1).time

    ctime = double to_date: Date.today.prev_day
    expect(File).to receive(:ctime).with(RelatonW3c::HitCollection::DATAFILE).
      and_return ctime

    # expect(Net::HTTP).to receive(:get_response)
    expect(File).to receive(:write).with(
      RelatonW3c::HitCollection::DATAFILE, any_args
    ).and_call_original

    VCR.use_cassette "data" do
      RelatonW3c::HitCollection.new "ref"
    end
  end
end

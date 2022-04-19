# RSpec.describe RelatonW3c::Scrapper do
#   it "fetch editors from hash" do
#     resp = double code: "301"
#     expect(Net::HTTP).to receive(:get_response).and_return resp
#     hit = { "link" => "http://other.domain/document", "editor" => ["Editor"] }
#     doc = RelatonW3c::Scrapper.parse_page hit
#     expect(doc.contributor[0].entity.name.completename.content).to eq "Editor"
#   end
# end

RSpec.describe RelatonW3c do
  it "has a version number" do
    expect(RelatonW3c::VERSION).not_to be nil
  end

  it "search hits" do
    VCR.use_cassette "data" do
      hits = RelatonW3c::W3cBibliography.search "JSON-LD 1.1"
      expect(hits).to be_instance_of RelatonW3c::HitCollection
      expect(hits.first).to be_instance_of RelatonW3c::Hit
    end
  end

  context "get document" do
    it "by title only" do
      VCR.use_cassette "data" do
        VCR.use_cassette "cr_json_ld11" do
          doc = RelatonW3c::W3cBibliography.get "W3C JSON-LD 1.1"
          expect(doc).to be_instance_of RelatonW3c::W3cBibliographicItem
        end
      end
    end

    it "with type" do
      VCR.use_cassette "data" do
        VCR.use_cassette "cr_json_ld11" do
          doc = RelatonW3c::W3cBibliography.get "W3C Candidate Recommendation JSON-LD 1.1"
          expect(doc).to be_instance_of RelatonW3c::W3cBibliographicItem
        end
      end
    end

    it "with short type" do
      VCR.use_cassette "data" do
        VCR.use_cassette "cr_json_ld11" do
          doc = RelatonW3c::W3cBibliography.get "W3C CR JSON-LD 1.1"
          expect(doc).to be_instance_of RelatonW3c::W3cBibliographicItem
        end
      end
    end

    context "from history" do
      it "with type" do
        VCR.use_cassette "data" do
          VCR.use_cassette "json_ld_1_1_history" do
            VCR.use_cassette "wd_json_ld11" do
              doc = RelatonW3c::W3cBibliography.get "W3C Working Draft JSON-LD 1.1"
              expect(doc).to be_instance_of RelatonW3c::W3cBibliographicItem
            end
          end
        end
      end

      it "with short type" do
        VCR.use_cassette "data" do
          VCR.use_cassette "json_ld_1_1_history" do
            VCR.use_cassette "wd_json_ld11" do
              doc = RelatonW3c::W3cBibliography.get "W3C WD JSON-LD 1.1"
              expect(doc).to be_instance_of RelatonW3c::W3cBibliographicItem
            end
          end
        end
      end

      it "with date" do
        VCR.use_cassette "data" do
          VCR.use_cassette "json_ld_1_1_history" do
            VCR.use_cassette "wd_json_ld11_20191018" do
              doc = RelatonW3c::W3cBibliography.get "W3C JSON-LD 1.1 2019-10-18"
              expect(doc).to be_instance_of RelatonW3c::W3cBibliographicItem
            end
          end
        end
      end

      it "with type and date" do
        VCR.use_cassette "data" do
          VCR.use_cassette "json_ld_1_1_history" do
            VCR.use_cassette "wd_json_ld11_20191018" do
              doc = RelatonW3c::W3cBibliography.get "W3C WD JSON-LD 1.1 2019-10-18"
              expect(doc).to be_instance_of RelatonW3c::W3cBibliographicItem
            end
          end
        end
      end

      it "with incorrect type and date" do
        VCR.use_cassette "data" do
          VCR.use_cassette "json_ld_1_1_history" do
            doc = RelatonW3c::W3cBibliography.get "W3C CR JSON-LD 1.1 2019-10-18"
            expect(doc).to be_nil
          end
        end
      end
    end
  end
end

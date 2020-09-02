require "jing"

RSpec.describe RelatonW3c do
  it "has a version number" do
    expect(RelatonW3c::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = RelatonW3c.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
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
          file = "spec/fixtures/cr_json_ld11.xml"
          xml = doc.to_xml bibdata: true
          File.write file, xml, encoding: "UTF-8" unless File.exist? file
          expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8").
            gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
          schema = Jing.new "spec/fixtures/isobib.rng"
          errors = schema.validate file
          expect(errors).to eq []
        end
      end
    end

    it "with type" do
      VCR.use_cassette "data" do
        VCR.use_cassette "cr_json_ld11" do
          doc = RelatonW3c::W3cBibliography.get "W3C Candidate Recommendation "\
            "JSON-LD 1.1"
          expect(doc.title.first.title.content).to eq "JSON-LD 1.1"
          expect(doc.doctype).to eq "candidateRecommendation"
        end
      end
    end

    it "with short type" do
      VCR.use_cassette "data" do
        VCR.use_cassette "cr_json_ld11" do
          doc = RelatonW3c::W3cBibliography.get "W3C CR JSON-LD 1.1"
          expect(doc.title.first.title.content).to eq "JSON-LD 1.1"
          expect(doc.doctype).to eq "candidateRecommendation"
        end
      end
    end

    context "from history" do
      it "with type" do
        VCR.use_cassette "data" do
          VCR.use_cassette "json_ld_1_1_history" do
            VCR.use_cassette "wd_json_ld11" do
              doc = RelatonW3c::W3cBibliography.get "W3C Working Draft JSON-LD 1.1"
              expect(doc.title.first.title.content).to eq "JSON-LD 1.1"
              expect(doc.doctype).to eq "workingDraft"
            end
          end
        end
      end

      it "with short type" do
        VCR.use_cassette "data" do
          VCR.use_cassette "json_ld_1_1_history" do
            VCR.use_cassette "wd_json_ld11" do
              doc = RelatonW3c::W3cBibliography.get "W3C WD JSON-LD 1.1"
              expect(doc.title.first.title.content).to eq "JSON-LD 1.1"
              expect(doc.doctype).to eq "workingDraft"
              expect(doc.date.first.on.to_s).to eq "2019-11-12"
            end
          end
        end
      end

      it "with date" do
        VCR.use_cassette "data" do
          VCR.use_cassette "json_ld_1_1_history" do
            VCR.use_cassette "wd_json_ld11_20191018" do
              doc = RelatonW3c::W3cBibliography.get "W3C JSON-LD 1.1 2019-10-18"
              expect(doc.title.first.title.content).to eq "JSON-LD 1.1"
              expect(doc.date.first.on.to_s).to eq "2019-10-18"
            end
          end
        end
      end

      it "with type and date" do
        VCR.use_cassette "data" do
          VCR.use_cassette "json_ld_1_1_history" do
            VCR.use_cassette "wd_json_ld11_20191018" do
              doc = RelatonW3c::W3cBibliography.get "W3C WD JSON-LD 1.1 2019-10-18"
              expect(doc.title.first.title.content).to eq "JSON-LD 1.1"
              expect(doc.doctype).to eq "workingDraft"
              expect(doc.date.first.on.to_s).to eq "2019-10-18"
            end
          end
        end
      end

      it "document from another site" do
        VCR.use_cassette "data" do
          VCR.use_cassette "dom" do
            doc = RelatonW3c::W3cBibliography.get "W3C DOM"
            expect(doc.title.first.title.content).to eq "DOM"
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

      it "HTML5" do
        VCR.use_cassette "data" do
          VCR.use_cassette "html5" do
            doc = RelatonW3c::W3cBibliography.get "W3C HTML5"
            expect(doc.title.first.title.content).to eq "HTML5"
          end
        end
      end

      it "W3C xmlschema-1" do
        VCR.use_cassette "data" do
          VCR.use_cassette "w3c_xmlschema_1" do
            doc = RelatonW3c::W3cBibliography.get "W3C xmlschema-1"
            expect(doc.title.first.title.content).to eq(
              "XML Schema Part 1: Structures Second Edition"
            )
          end
        end
      end

      it "W3C REC-xml-names-20091208" do
        VCR.use_cassette "data" do
          VCR.use_cassette "rec_xml_names_20091208" do
            doc = RelatonW3c::W3cBibliography.get "W3C REC-xml-names-20091208"
            expect(doc.title.first.title.content).to eq(
              "Namespaces in XML 1.0 (Third Edition)"
            )
          end
        end
      end
    end
  end
end

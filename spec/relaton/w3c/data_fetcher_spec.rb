# frozen_string_literal: true

require_relative "../../../lib/relaton/w3c/data_fetcher"

RSpec.describe Relaton::W3c::DataFetcher do
  it "create output dir and run fetcher" do
    expect(FileUtils).to receive(:mkdir_p).with("dir")
    fetcher = double("fetcher")
    expect(fetcher).to receive(:fetch).with(nil)
    expect(described_class).to receive(:new).with("dir", "xml").and_return(fetcher)
    described_class.fetch output: "dir", format: "xml"
  end

  describe ".fetch_versions?" do
    around do |ex|
      orig = ENV["RELATON_W3C_FETCH_VERSIONS"]
      ex.run
      ENV["RELATON_W3C_FETCH_VERSIONS"] = orig
    end

    it "defaults to true when unset" do
      ENV.delete("RELATON_W3C_FETCH_VERSIONS")
      expect(described_class.fetch_versions?).to be true
    end

    it "is false for falsey values" do
      %w[false 0 no off FALSE Off].each do |v|
        ENV["RELATON_W3C_FETCH_VERSIONS"] = v
        expect(described_class.fetch_versions?).to be(false), "expected #{v.inspect} to disable"
      end
    end

    it "is true for any other value" do
      ENV["RELATON_W3C_FETCH_VERSIONS"] = "true"
      expect(described_class.fetch_versions?).to be true
    end
  end

  context "instance" do
    subject { described_class.new("dir", "bibxml") }
    let(:index) { double("index") }

    before do
      allow(Relaton::Index).to receive(:find_or_create)
        .with(:W3C, file: "index-v1.yaml").and_return(index)
    end

    it "initialize fetcher" do
      expect(subject.instance_variable_get(:@ext)).to eq "xml"
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "bibxml"
      expect(subject).to be_instance_of(described_class)
    end

    context "#fetch" do
      let(:spec_link) { double("spec_link") }
      let(:spec_links) { double("spec_links", specifications: [spec_link]) }
      let(:specs) { double("specs", links: spec_links, pages: 1) }

      before do
        allow(index).to receive(:save)
      end

      it "iterates through paginated specifications by page number" do
        specs2_links = double("specs2_links", specifications: [spec_link])
        specs2 = double("specs2", links: specs2_links, page: 2)

        allow(specs).to receive_messages(page: 1, pages: 2)
        expect(specs).to receive(:next?).and_return(true)
        expect(specs2).to receive(:next?).and_return(false)

        client = double("client")
        # Page 1 fetched with embed, page 2 fetched via page-number param —
        # both through the client so embedded_data is populated each time.
        allow(client).to receive(:specifications).with(embed: true).and_return(specs)
        allow(client).to receive(:specifications).with(embed: true, page: 2).and_return(specs2)
        allow(subject).to receive(:client).and_return(client)
        allow(subject).to receive(:fetch_spec)

        subject.fetch

        expect(client).to have_received(:specifications).with(embed: true, page: 2)
      end

      it "fetches the index with embed and hands the page to fetch_spec" do
        allow(specs).to receive(:page).and_return(1)
        expect(specs).to receive(:next?).and_return(false)
        client = double("client")
        expect(client).to receive(:specifications).with(embed: true).and_return(specs)
        allow(subject).to receive(:client).and_return(client)
        expect(subject).to receive(:fetch_spec).with(spec_link, specs)
        subject.fetch
      end

      it "stops crawling when interrupted but still saves the index" do
        subject.instance_variable_set(:@interrupted, true)
        client = double("client")
        allow(client).to receive(:specifications).with(embed: true).and_return(specs)
        allow(subject).to receive(:client).and_return(client)

        # No spec is processed, but progress collected so far is still saved.
        expect(subject).not_to receive(:fetch_spec)
        expect(index).to receive(:save)

        expect { subject.fetch }
          .to output(/interrupted/i).to_stderr_from_any_process
      end

      it "restores the previous SIGINT handler after the crawl" do
        sentinel = ->(_sig) {}
        previous = Signal.trap("INT", sentinel)
        begin
          allow(specs).to receive(:page).and_return(1)
          allow(specs).to receive(:next?).and_return(false)
          client = double("client", specifications: specs)
          allow(subject).to receive(:client).and_return(client)
          allow(subject).to receive(:fetch_spec)

          subject.fetch

          expect(Signal.trap("INT", "DEFAULT")).to eq sentinel
        ensure
          Signal.trap("INT", previous || "DEFAULT")
        end
      end

      it "aborts without saving when a page fetch fails mid-pagination" do
        allow(specs).to receive_messages(page: 1, pages: 3)
        allow(specs).to receive(:next?).and_return(true)

        client = double("client")
        allow(client).to receive(:specifications).with(embed: true).and_return(specs)
        allow(client).to receive(:specifications).with(embed: true, page: 2)
          .and_raise(Lutaml::Hal::Error.new("rate limited"))
        allow(subject).to receive(:client).and_return(client)
        allow(subject).to receive(:fetch_spec)
        allow(subject).to receive(:sleep) # don't actually back off in the test

        # A failed page fetch must not be mistaken for end-of-list: the crawl
        # aborts and the (truncated) index is never saved.
        expect(index).not_to receive(:save)
        expect { subject.fetch }
          .to raise_error(described_class::CrawlIncompleteError, /page 1/)
      end

      it "aborts when pagination ends before the last advertised page" do
        allow(specs).to receive_messages(page: 1, pages: 3)
        allow(specs).to receive(:next?).and_return(false)

        client = double("client")
        allow(client).to receive(:specifications).with(embed: true).and_return(specs)
        allow(subject).to receive(:client).and_return(client)
        allow(subject).to receive(:fetch_spec)

        expect(index).not_to receive(:save)
        expect { subject.fetch }
          .to raise_error(described_class::CrawlIncompleteError, /page 1 of 3/)
      end
    end

    context "#fetch_specifications_page" do
      let(:client) { double("client") }
      let(:page) { double("page") }

      before do
        allow(subject).to receive(:client).and_return(client)
        allow(subject).to receive(:sleep) # keep backoff instant in tests
      end

      it "retries a transient failure and returns the page on success" do
        calls = 0
        allow(client).to receive(:specifications).with(embed: true, page: 2) do
          calls += 1
          raise Lutaml::Hal::Error, "rate limited" if calls < 2

          page
        end

        expect(subject.send(:fetch_specifications_page, 2)).to eq page
        expect(calls).to eq 2
      end

      it "returns nil after exhausting retries" do
        allow(client).to receive(:specifications).with(embed: true, page: 2)
          .and_raise(Lutaml::Hal::Error.new("rate limited"))

        expect(subject.send(:fetch_specifications_page, 2)).to be_nil
        expect(client).to have_received(:specifications)
          .with(embed: true, page: 2).exactly(described_class::PAGE_FETCH_ATTEMPTS).times
        expect(subject).to have_received(:sleep).exactly(described_class::PAGE_FETCH_ATTEMPTS - 1).times
      end
    end

    context "#fetch_spec" do
      let(:unrealized_spec) { double("unrealized_spec") }
      let(:bib) { double("bib") }
      let(:spec_links) { double("spec_links") }
      let(:spec) { double("spec", links: spec_links) }

      before do
        allow(subject).to receive(:realize).with(unrealized_spec, parent_resource: nil).and_return(spec)
        allow(Relaton::W3c::DataParser).to receive(:parse).with(spec, kind_of(Hash)).and_return(bib)
        allow(subject).to receive(:save_doc)
      end

      it "realizes spec and saves parsed doc" do
        allow(spec_links).to receive(:respond_to?).and_return(false)

        subject.fetch_spec(unrealized_spec)

        expect(subject).to have_received(:realize).with(unrealized_spec, parent_resource: nil)
        expect(Relaton::W3c::DataParser).to have_received(:parse).with(spec, kind_of(Hash))
        expect(subject).to have_received(:save_doc).with(bib).once
      end

      it "realizes the spec from the embedded page when given a parent page" do
        page = double("page")
        allow(subject).to receive(:realize).with(unrealized_spec, parent_resource: page).and_return(spec)
        allow(spec_links).to receive(:respond_to?).and_return(false)

        subject.fetch_spec(unrealized_spec, page)

        expect(subject).to have_received(:realize).with(unrealized_spec, parent_resource: page)
        expect(subject).to have_received(:save_doc).with(bib).once
      end

      it "skips version history when fetch_versions? is false" do
        allow(described_class).to receive(:fetch_versions?).and_return(false)
        # version_history etc. would be consulted only if fetch_versions ran;
        # respond_to? must never be asked when versions are skipped.
        expect(spec_links).not_to receive(:respond_to?)

        subject.fetch_spec(unrealized_spec)

        expect(subject).to have_received(:save_doc).with(bib).once
      end

      it "processes version_history" do
        version1 = double("version1")
        version2 = double("version2")
        realized_version1 = double("realized_version1")
        realized_version2 = double("realized_version2")
        bib_v1 = double("bib_v1")
        bib_v2 = double("bib_v2")
        vh_link = double("vh_link")
        vh_links = double("vh_links", spec_versions: [version1, version2])
        realized_vh = double("realized_vh", links: vh_links)

        allow(spec_links).to receive(:respond_to?).and_return(false)
        allow(spec_links).to receive(:respond_to?).with(:version_history).and_return(true)
        allow(spec_links).to receive(:version_history).and_return(vh_link)
        allow(subject).to receive(:realize).with(vh_link).and_return(realized_vh)
        allow(subject).to receive(:realize).with(version1).and_return(realized_version1)
        allow(subject).to receive(:realize).with(version2).and_return(realized_version2)
        allow(Relaton::W3c::DataParser).to receive(:parse).with(realized_version1).and_return(bib_v1)
        allow(Relaton::W3c::DataParser).to receive(:parse).with(realized_version2).and_return(bib_v2)

        subject.fetch_spec(unrealized_spec)

        expect(subject).to have_received(:save_doc).with(bib)
        expect(subject).to have_received(:save_doc).with(bib_v1)
        expect(subject).to have_received(:save_doc).with(bib_v2)
        expect(subject).to have_received(:save_doc).exactly(3).times
      end

      it "processes predecessor_versions" do
        version = double("version")
        realized_version = double("realized_version")
        bib_v = double("bib_v")
        pv_link = double("pv_link")
        pv_links = double("pv_links", predecessor_versions: [version])
        realized_pv = double("realized_pv", links: pv_links)

        allow(spec_links).to receive(:respond_to?).and_return(false)
        allow(spec_links).to receive(:respond_to?).with(:predecessor_versions).and_return(true)
        allow(spec_links).to receive(:predecessor_versions).and_return(pv_link)
        allow(subject).to receive(:realize).with(pv_link).and_return(realized_pv)
        allow(subject).to receive(:realize).with(version).and_return(realized_version)
        allow(Relaton::W3c::DataParser).to receive(:parse).with(realized_version).and_return(bib_v)

        subject.fetch_spec(unrealized_spec)

        expect(subject).to have_received(:save_doc).with(bib)
        expect(subject).to have_received(:save_doc).with(bib_v)
        expect(subject).to have_received(:save_doc).exactly(2).times
      end

      it "processes successor_versions" do
        version = double("version")
        realized_version = double("realized_version")
        bib_v = double("bib_v")
        sv_link = double("sv_link")
        sv_links = double("sv_links", successor_versions: [version])
        realized_sv = double("realized_sv", links: sv_links)

        allow(spec_links).to receive(:respond_to?).and_return(false)
        allow(spec_links).to receive(:respond_to?).with(:successor_versions).and_return(true)
        allow(spec_links).to receive(:successor_versions).and_return(sv_link)
        allow(subject).to receive(:realize).with(sv_link).and_return(realized_sv)
        allow(subject).to receive(:realize).with(version).and_return(realized_version)
        allow(Relaton::W3c::DataParser).to receive(:parse).with(realized_version).and_return(bib_v)

        subject.fetch_spec(unrealized_spec)

        expect(subject).to have_received(:save_doc).with(bib)
        expect(subject).to have_received(:save_doc).with(bib_v)
        expect(subject).to have_received(:save_doc).exactly(2).times
      end
    end

    context "#save_doc" do
      let(:bib) { double("bib", docnumber: "W3C REC-xml-names") }

      it "skip on nil" do
        expect(subject).not_to receive(:file_name)
        subject.save_doc nil
      end

      context "new file" do
        before do
          allow(index).to receive(:add_or_update)
        end

        it "bibxml format" do
          expect(bib).to receive(:to_xml).with(no_args).and_return("<xml/>")
          expect(File).to receive(:write)
            .with("dir/rec-xml-names.xml", "<xml/>", encoding: "UTF-8")
          subject.save_doc bib
          expect(index).to have_received(:add_or_update)
            .with(kind_of(Hash), "dir/rec-xml-names.xml")
        end

        it "xml format" do
          subject.instance_variable_set(:@format, "xml")
          expect(bib).to receive(:to_xml).with(bibdata: true).and_return("<xml/>")
          expect(File).to receive(:write)
            .with("dir/rec-xml-names.xml", "<xml/>", encoding: "UTF-8")
          subject.save_doc bib
          expect(index).to have_received(:add_or_update)
            .with(kind_of(Hash), "dir/rec-xml-names.xml")
        end

        it "yaml format" do
          subject.instance_variable_set(:@format, "yaml")
          subject.instance_variable_set(:@ext, "yaml")
          expect(bib).to receive(:to_yaml).and_return("---\nid: 123\n")
          expect(File).to receive(:write)
            .with("dir/rec-xml-names.yaml", "---\nid: 123\n", encoding: "UTF-8")
          subject.save_doc bib
          expect(index).to have_received(:add_or_update)
            .with(kind_of(Hash), "dir/rec-xml-names.yaml")
        end
      end

      context "when file already exists" do
        before do
          subject.instance_variable_get(:@files) << "dir/rec-xml-names.xml"
          allow(bib).to receive(:to_xml).with(no_args).and_return("<xml/>")
          allow(File).to receive(:write)
        end

        it "warns about duplicate" do
          expect { subject.save_doc bib }
            .to output(/File dir\/rec-xml-names.xml already exists/).to_stderr_from_any_process
        end

        it "suppresses warning with warn_duplicate: false" do
          expect { subject.save_doc bib, warn_duplicate: false }
            .not_to output.to_stderr_from_any_process
        end
      end
    end

    context "#file_name" do
      it "converts document ID to file path" do
        expect(subject.file_name("W3C REC-xml-names")).to eq "dir/rec-xml-names.xml"
      end

      it "handles special characters" do
        expect(subject.file_name("W3C CR/json:ld+11 test"))
          .to eq "dir/cr_json_ld_11_test.xml"
      end
    end
  end
end

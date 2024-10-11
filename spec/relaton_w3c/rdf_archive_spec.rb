describe RelatonW3c::RDFArchive do
  let(:older) { File.read "spec/fixtures/older.rdf" }
  let(:newer) { File.read "spec/fixtures/newer.rdf" }
  let(:merged) { File.read "spec/fixtures/merged.rdf" }
  let(:tr_rdf_url) { "http://www.w3.org/2002/01/tr-automation/tr.rdf" }
  let(:archive_url) { "https://raw.githubusercontent.com/relaton/relaton-data-w3c/refs/heads/main/archive.rdf" }

  it "update_archive" do
    expect(File).to receive(:read).with("archive.rdf", encoding: "UTF-8").and_return older
    allow(File).to receive(:read).and_call_original
    resp = double read: newer
    expect(OpenURI).to receive(:open_uri).with(tr_rdf_url).and_return resp
    expect(File).to receive(:write).with("archive.rdf", merged, encoding: "UTF-8")
    subject.send(:update_archive)
  end

  context "get_data" do
    it "current is actual" do
      expect(File).to receive(:exist?).with("archive.rdf").and_return true
      expect(File).to receive(:mtime).with("archive.rdf").and_return Time.now
      expect(RDF::Repository).to receive(:load).with("archive.rdf").and_return :rdf
      expect(subject.get_data).to eq :rdf
    end

    context do
      before do
        expect(subject).to receive(:update_archive)
        expect(subject).to receive(:get_archive)
        allow(File).to receive(:exist?).and_call_original
      end

      it "update outdated" do
        expect(File).to receive(:exist?).with("archive.rdf").and_return true
        expect(File).to receive(:mtime).with("archive.rdf").and_return Time.now - 86_400
        expect(RDF::Repository).to receive(:load).with("archive.rdf").and_return :rdf
        expect(subject.get_data).to eq :rdf
      end

      it "no archive" do
        expect(File).to receive(:exist?).with("archive.rdf").and_return false
        expect(RDF::Repository).to receive(:load).with("archive.rdf").and_return :rdf
        expect(subject.get_data).to eq :rdf
      end
    end
  end

  context "get_archive" do
    it "read existing" do
      expect(File).to receive(:exist?).with("archive.rdf").and_return true
      expect(File).not_to receive(:write)
      subject.send(:get_archive)
    end

    it "download" do
      expect(File).to receive(:exist?).with("archive.rdf").and_return false
      resp = double read: merged
      expect(OpenURI).to receive(:open_uri).with(archive_url).and_return resp
      expect(File).to receive(:write).with("archive.rdf", merged, encoding: "UTF-8")
      subject.send(:get_archive)
    end
  end
end

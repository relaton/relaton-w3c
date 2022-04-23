RSpec.describe RelatonW3c::DataIndex do
  subject { RelatonW3c::DataIndex.new }

  context "initialize data index" do
    it "without filename & data" do
      expect(subject.instance_variable_get(:@index_file)).to eq "index-w3c.yaml"
      expect(subject.instance_variable_get(:@index)).to eq []
    end

    it "with filename" do
      dindex = RelatonW3c::DataIndex.new index_file: "index.yaml"
      expect(dindex.instance_variable_get(:@index_file)).to eq "index.yaml"
    end

    it "with data" do
      dindex = RelatonW3c::DataIndex.new index: [{ code: "2dcontext" }]
      expect(dindex.instance_variable_get(:@index)).to eq [{ code: "2dcontext" }]
    end
  end

  context "instance" do
    it "add file to index" do
      subject.add "bib", "dir/bib.xml"
      expect(subject.instance_variable_get(:@index)).to eq [{ file: "dir/bib.xml", code: "bib" }]
    end

    it "docnumber to parts" do
      parts = subject.class.docnumber_to_parts "REC-CSS2-19980512/fonts"
      expect(parts).to eq(
        stage: "REC", code: "CSS2",
        date: "19980512", suff: "fonts"
      )
    end

    it "save index" do
      subject.instance_variable_set(:@index, [{ code: "2dcontext2" }, { code: "2dcontext" }])
      output = "---\n- :code: 2dcontext\n- :code: 2dcontext2\n"
      expect(File).to receive(:write).with("index-w3c.yaml", output, encoding: "UTF-8")
      subject.sort!.save
    end

    context "compare index items" do
      it "code" do
        a = { code: "2dcontext" }
        b = { code: "2dcontext2" }
        expect(subject.compare_index_items(a, b)).to eq(-1)
      end

      it "code & date" do
        a = { code: "2dcontext", date: "20151119" }
        b = { code: "2dcontext", date: "20210128" }
        expect(subject.compare_index_items(a, b)).to eq(1)
      end

      it "code & stage" do
        a = { code: "2dcontext", stage: "WD" }
        b = { code: "2dcontext", stage: "REC" }
        expect(subject.compare_index_items(a, b)).to eq(1)
      end

      it "code vs code & stage" do
        a = { code: "2dcontext" }
        b = { code: "2dcontext", stage: "REC" }
        expect(subject.compare_index_items(a, b)).to eq(-1)
      end

      it "code vs code & date" do
        a = { code: "2dcontext" }
        b = { code: "2dcontext", date: "20210128" }
        expect(subject.compare_index_items(a, b)).to eq(-1)
      end
    end
  end
end

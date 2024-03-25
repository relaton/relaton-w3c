describe RelatonW3c::DocumentType do
  before { RelatonW3c.instance_variable_set :@configuration, nil }

  it "invalid document type warning" do
    expect do
      described_class.new type: "invalid_type"
    end.to output(/\[relaton-w3c\] WARN: invalid doctype: `invalid_type`/).to_stderr_from_any_process
  end
end

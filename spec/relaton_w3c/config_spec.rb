describe RelatonW3c do
  after { RelatonW3c.instance_variable_set :@configuration, nil }

  it "configure" do
    RelatonW3c.configure do |conf|
      conf.logger = :logger
    end
    expect(RelatonW3c.configuration.logger).to eq :logger
  end
end

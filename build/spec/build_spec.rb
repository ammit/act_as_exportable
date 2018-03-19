RSpec.describe Build do
  it "has a version number" do
    expect(Build::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end

# require 'act_as_exportable'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe ActAsExportable do

  before(:each) do
    ActiveRecord::Base.connection.execute %{
      TRUNCATE TABLE test_models;
      SELECT setval('test_models_id_seq', 1, false);
    }
  end

  it "has a version number" do
    expect(ActAsExportable::VERSION).not_to be nil
  end

  it "should import from file" do
    TestModel.import_csv File.expand_path('spec/fixtures/sample.csv')
    TestModel.order(:id).map{|r| r.attributes}.should == [{'id' => 1, 'data' => 'india'}]
  end
end

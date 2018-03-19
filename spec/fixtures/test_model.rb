require "spec_helper"
# require 'act_as_exportable'

class TestModel < ActiveRecord::Base
  act_as_exportable attributes: %w|id name|,
    required_columns: %w|name|
end
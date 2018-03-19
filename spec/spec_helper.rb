$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'active_record'
# require 'fixtures/test_model'
# require 'fixtures/test_extended_model'
# require 'fixtures/extra_field'
# require 'fixtures/test_model'
require 'rspec'
require 'rspec/autorun'


RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end


  config.before(:suite) do
    # we create a test database if it does not exist
    # I do not use database users or password for the tests, using ident authentication instead
    begin
      ActiveRecord::Base.establish_connection(
        :adapter  => "postgresql",
        :host     => "localhost",
        :username => "postgres",
        :password => "postgres",
        :port     => 5432,
        :database => "ar_pg_copy_test"
      )
      ActiveRecord::Base.connection.execute %{
        SET client_min_messages TO warning;
        DROP TABLE IF EXISTS test_models;
        CREATE TABLE test_models (id serial PRIMARY KEY, data text);
      }
    rescue Exception => e
      puts "Exception: #{e}"
      ActiveRecord::Base.establish_connection(
        :adapter  => "postgresql",
        :host     => "localhost",
        :username => "postgres",
        :password => "postgres",
        :port     => 5432,
        :database => "postgres"
      )
      ActiveRecord::Base.connection.execute "CREATE DATABASE ar_pg_copy_test"
      retry
    end
  end

end

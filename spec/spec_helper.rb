if RUBY_VERSION =~ /^1\.9/
  require 'ruby-debug'
elsif RUBY_VERSION =~ /^2\.0/
  require 'pry'
end
require_relative '../lib/libertree/db'

########################
# FIXME: Sequel wants us to connect to the db before defining models.  As model
# definitions are loaded when 'libertree/model' is required, we have to do
# this first.
Libertree::DB.load_config "#{File.dirname( __FILE__ ) }/../database.yaml"
Libertree::DB.dbh
########################

require_relative '../lib/libertree/model'
require 'database_cleaner'
require_relative 'factories'

if ENV['LIBERTREE_ENV'] != 'test'
  $stderr.puts "Refusing to run specs in a non-test environment.  Comment out the exit line if you know what you're doing."
  exit 1
end

# So that FactoryGirl can be used with Sequel
class Sequel::Model
  alias_method :save!, :save
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
    DatabaseCleaner.clean

    Libertree::Model::Server.own_domain = "localhost.net"
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

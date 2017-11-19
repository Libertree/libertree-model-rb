source 'http://rubygems.org'
gem 'sequel', '< 5'
gem 'ruby-oembed'
gem 'net-ldap'

group 'extensions' do
  gem 'json'
  gem 'parkdown-libertree'
  gem 'pg'
  gem 'bcrypt-ruby'
  gem 'nokogiri'
  gem 'gpgme'
end

group 'development' do
  gem 'linecache19', :git => 'git://github.com/mark-moseley/linecache', :platforms => [:ruby_19]
  gem 'pry-byebug', platforms: [:ruby_20]
  gem 'ruby-debug-base19x', '~> 0.11.30.pre4', :platforms => [:ruby_19]
  gem 'ruby-debug19', :platforms => [:ruby_19]
end

group 'test' do
  gem 'database_cleaner'
  gem 'factory_girl'
  gem 'rspec'
end

source 'http://rubygems.org'

gem 'net-ldap', '~> 0.16.1'
gem 'ruby-oembed', '~> 0.12.0'
gem 'sequel', '< 5'

group 'extensions' do
  gem 'bcrypt-ruby', '~> 3.1.5'
  gem 'gpgme', '~> 2.0.19'
  gem 'json', '~> 2.2.0'
  gem 'nokogiri', '~> 1.10.4'
  gem 'parkdown-libertree'
  gem 'pg', '~> 0.21.0'
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

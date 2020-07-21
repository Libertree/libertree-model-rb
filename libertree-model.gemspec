Gem::Specification.new do |s|
  s.name        = 'libertree-model'
  s.version     = '0.9.16'
  s.date        = '2020-07-21'
  s.summary     = "Database library for Libertree"
  s.description = "Database library for Libertree"
  s.authors     = ["Pistos", "rekado"]
  # s.email       = ''
  s.files       = Dir["lib/**/*"]
  s.homepage    = 'http://libertree.org/'

  s.add_dependency 'ruby-oembed', '~> 0.13.1'
  s.add_dependency 'gpgme', '~> 2.0.20'
  s.add_dependency 'pg', '~> 1.2.3'
  s.add_dependency 'sequel', '~> 5.34.0'
  s.add_dependency 'bcrypt-ruby', '~> 3.1.5'
  s.add_dependency 'nokogiri', '~> 1.10.10'
  s.add_dependency 'net-ldap', '~> 0.16.1'
  s.add_dependency 'parkdown-libertree', '~> 1.4.26'
end

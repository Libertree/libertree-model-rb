Gem::Specification.new do |s|
  s.name        = 'libertree-model'
  s.version     = '0.9.11'
  s.date        = '2017-11-18'
  s.summary     = "Database library for Libertree"
  s.description = "Database library for Libertree"
  s.authors     = ["Pistos", "rekado"]
  # s.email       = ''
  s.files       = Dir["lib/**/*"]
  s.homepage    = 'http://libertree.org/'

  s.add_dependency 'ruby-oembed', '~> 0.8.8'
  s.add_dependency 'gpgme'
  s.add_dependency 'pg'
  s.add_dependency 'sequel', '< 5'
  s.add_dependency 'bcrypt-ruby', '= 3.0.1'
  s.add_dependency 'nokogiri', '~> 1.5'
  s.add_dependency 'net-ldap', '~> 0.5.1'
  s.add_dependency 'parkdown-libertree', '~> 1.4.27'
end

# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rack/tfg_auth/version'

Gem::Specification.new do |gem|
  gem.name          = "rack-tfg_auth"
  gem.version       = Rack::TfgAuth::VERSION
  gem.authors       = ["Leanardo Bessa"]
  gem.email         = ["leobessa@gmail.com"]
  gem.description   = %q{Rack middleware for using the Authorization header with TFG authentication}
  gem.summary       = %q{Rack middleware for using the Authorization header with TFG authentication}
  gem.homepage      = "https://github.com/leobessa/rack-tfg_auth"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "rack"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jwt_authentication/version'

Gem::Specification.new do |spec|
  spec.name          = "jwt_authentication"
  spec.version       = "0.1"
  spec.authors       = ["Auctionet"]
  spec.email         = ["devs@auctionet.com"]

  spec.summary       = %q{}
  spec.description   = %q{}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "sinatra"
  spec.add_development_dependency "timecop"

  spec.add_dependency "attr_extras"
  spec.add_dependency "jwt"
  spec.add_dependency "memoit"
end

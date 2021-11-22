# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jwt_authentication/version"

Gem::Specification.new do |spec|
  spec.name          = "jwt_authentication"
  spec.version       = JwtAuthentication::VERSION
  spec.authors       = [ "Auctionet" ]
  spec.email         = [ "devs@auctionet.com" ]

  spec.summary       = %q{}
  spec.description   = %q{}
  spec.homepage      = ""
  spec.license       = "MIT"
  spec.metadata      = { "rubygems_mfa_required" => "true" }

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "attr_extras"
  spec.add_dependency "jwt"
  spec.add_dependency "memoit"
end

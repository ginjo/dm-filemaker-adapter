# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dm-filemaker-adapter/version'

Gem::Specification.new do |spec|
  spec.name          = "dm-filemaker-adapter"
  spec.version       = DataMapper::FilemakerAdapter::VERSION
  spec.authors       = ["William Richardson"]
  spec.email         = ["https://github.com/ginjo/dm-filemaker-adapter"]
  spec.summary       = %q{Filemaker adapter for DataMapper}
  spec.description   = %q{Use Filemaker Server as a datastore for DataMapper ORM}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  
  spec.add_dependency "data_mapper"
  spec.add_dependency "ginjo-rfm"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end

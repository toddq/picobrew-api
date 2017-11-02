# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "picobrew-api"
  spec.version       = "0.1.3"
  spec.authors       = ["Todd Quessenberry"]
  spec.email         = ["todd@quessenberry.com"]

  spec.summary       = %q{Provides a library to access your Picobrew data}
  spec.homepage      = "https://github.com/toddq/picobrew-api"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_runtime_dependency "httparty", "~> 0.15"
  spec.add_runtime_dependency "nokogiri", "~> 1.8"
end

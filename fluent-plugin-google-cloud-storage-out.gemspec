# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fluent/plugin/version'

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-google-cloud-storage-out"
  spec.version       = GoogleCloudStorageOut::VERSION
  spec.authors       = ["Hideki Matsuoka"]
  spec.email         = ["matsuoka.hide@gmail.com"]

  spec.summary       = %q{Fluentd out plugin for store to Google Cloud Storage}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/matsuokah/fluent-plugin-google-cloud-storage-out"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # development dependency
  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"

  # runtime dependency
  spec.add_runtime_dependency "fluentd", ">= 0.10.60"
  spec.add_runtime_dependency "fluent-mixin-config-placeholders", ">= 0.3.0"
  spec.add_runtime_dependency "googleauth", ">= 0.5"
  spec.add_runtime_dependency "google-api-client", "0.9.pre5"
  spec.add_runtime_dependency "mime-types", ">= 3.0"
end

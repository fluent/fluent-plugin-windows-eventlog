# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-windows-eventlog"
  spec.version       = "0.2.2"
  spec.authors       = ["okahashi117", "Hiroshi Hatake", "Masahiro Nakagawa"]
  spec.email         = ["naruki_okahashi@jbat.co.jp", "cosmo0920.oucc@gmail.com", "repeatedly@gmail.com"]
  spec.summary       = %q{Fluentd Input plugin to read windows event log.}
  spec.description   = %q{Fluentd Input plugin to read windwos event log.}
  spec.homepage      = "https://github.com/fluent/fluent-plugin-windows-eventlog"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "test-unit", "~> 3.2.0"
  spec.add_runtime_dependency "fluentd", [">= 0.14.12", "< 2"]
  spec.add_runtime_dependency "win32-eventlog"
end

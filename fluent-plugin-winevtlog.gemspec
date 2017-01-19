# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-windows-eventlog"
  spec.version       = "0.0.4"
  spec.authors       = ["okahashi117"]
  spec.email         = ["naruki_okahashi@jbat.co.jp"]
  spec.summary       = %q{Input plugin to read windows event log.}
  spec.description   = %q{Input plugin to read windwos event log.}
  spec.homepage      = ""
  spec.license       = "Apache license"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_runtime_dependency "fluentd"
  spec.add_runtime_dependency "win32-eventlog"
end

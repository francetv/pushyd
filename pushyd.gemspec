# coding: utf-8

# Gemspec
Gem::Specification.new do |spec|
  spec.name = "pushyd"
  spec.date = Time.now.strftime("%Y-%m-%d")
  spec.authors = ["Bruno MEDICI"]
  spec.email = "pushyd@bmconseil.com"
  spec.description = ""
  spec.summary = ""
  spec.homepage = "http://github.com/bmedici/pushyd"
  spec.licenses = ["MIT"]

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    # f == "dashboard.png"
  end
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.version       = "0.1"

  spec.required_ruby_version = ">= 2.2"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "http", "~> 0.8"
  spec.add_development_dependency "rubocop", "~> 0.32.0"
  # spec.add_development_dependency "pry"

  spec.add_runtime_dependency "daemons"
  spec.add_runtime_dependency "chamber"
  spec.add_runtime_dependency "json"
  # spec.add_runtime_dependency "newrelic_rpm"
end

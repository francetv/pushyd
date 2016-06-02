# coding: utf-8
Gem::Specification.new do |spec|
  # Project version
  spec.version                = "0.0.1"

  # Project description
  spec.name                         = "pushyd"
  spec.authors                      = ["Bruno MEDICI"]
  spec.email                        = "pushyd@bmconseil.com"
  spec.description                  = "(description to be written)"
  spec.summary                      = "(summary to be written)"
  spec.homepage                     = "http://github.com/bmedici/pushyd"
  spec.licenses                     = ["MIT"]
  spec.date                         = Time.now.strftime("%Y-%m-%d")

  # List files and executables
  spec.files                        = `git ls-files -z`.split("\x0").reject{ |f| f == "dashboard.png"}
  spec.executables                  = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths                = ["lib"]
  spec.required_ruby_version        = ">= 2.2"

  # Development dependencies
  spec.add_development_dependency   "bundler", "~> 1.6"
  spec.add_development_dependency   "rake"
  spec.add_development_dependency   "rspec"
  spec.add_development_dependency   "http", "~> 0.8"
  spec.add_development_dependency   "rubocop", "~> 0.32.0"
  # spec.add_development_dependency "pry"

  # Runtime dependencies
  spec.add_runtime_dependency       "daemons"
  spec.add_runtime_dependency       "chamber"
  spec.add_runtime_dependency       "json"
  spec.add_runtime_dependency       "bunny"
  spec.add_runtime_dependency       "rest_client"
  spec.add_runtime_dependency       "terminal-table"
  # spec.add_runtime_dependency "newrelic_rpm"
end

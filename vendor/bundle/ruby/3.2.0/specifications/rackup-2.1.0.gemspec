# -*- encoding: utf-8 -*-
# stub: rackup 2.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rackup".freeze
  s.version = "2.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Samuel Williams".freeze, "Jeremy Evans".freeze]
  s.date = "2023-01-27"
  s.executables = ["rackup".freeze]
  s.files = ["bin/rackup".freeze]
  s.homepage = "https://github.com/rack/rackup".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.4.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A general server command for Rack applications.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rack>.freeze, [">= 3"])
  s.add_runtime_dependency(%q<webrick>.freeze, ["~> 1.8"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.0"])
  s.add_development_dependency(%q<minitest-global_expectations>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest-sprint>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
end

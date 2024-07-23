# frozen_string_literal: true

require_relative "lib/actual_db_schema/version"

Gem::Specification.new do |spec|
  spec.name = "actual_db_schema"
  spec.version = ActualDbSchema::VERSION
  spec.authors = ["Andrei Kaleshka"]
  spec.email = ["ka8725@gmail.com"]

  spec.summary = "Keep your DB and schema.rb consistent in dev branches."
  spec.description = <<~DESC
    Wipe out inconsistent DB and schema.rb when switching branches.
    Just install this gem and use the standard rake db:migrate command.
  DESC
  spec.homepage = "https://blog.widefix.com/actual-db-schema/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/widefix/actual_db_schema"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_runtime_dependency "activerecord"
  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "csv"

  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "debug"
  spec.add_development_dependency "rails"
  spec.add_development_dependency "sqlite3"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

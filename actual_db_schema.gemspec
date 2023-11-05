# frozen_string_literal: true

require_relative "lib/actual_db_schema/version"

Gem::Specification.new do |spec|
  spec.name = "actual_db_schema"
  spec.version = ActualDbSchema::VERSION
  spec.authors = ["Andrei Kaleshka"]
  spec.email = ["ka8725@gmail.com"]

  spec.summary = "Keep your DB clean and consistent between branches."
  spec.description = <<~DESC
    Switching between branches with migrations and running them can make your DB inconsistent
    and not working in another branch if not roll the migration back.
    Install this gem and forget about that issue by running the standard rake db:migrate.
  DESC
  spec.homepage = "https://github.com/widefix/actual_db_schema"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
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
  spec.add_runtime_dependency "activerecord", ">= 6.0.0"
  spec.add_runtime_dependency "activesupport", ">= 6.0.0"

  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "debug"
  spec.add_development_dependency "rails"
  spec.add_development_dependency "sqlite3"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

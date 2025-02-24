# frozen_string_literal: true

namespace :actual_db_schema do # rubocop:disable Metrics/BlockLength
  desc "Install ActualDbSchema initializer and post-checkout git hook."
  task :install do
    extend ActualDbSchema::OutputFormatter

    initializer_path = Rails.root.join("config", "initializers", "actual_db_schema.rb")
    initializer_content = File.read(
      File.expand_path("../../lib/generators/actual_db_schema/templates/actual_db_schema.rb", __dir__)
    )

    if File.exist?(initializer_path)
      puts colorize("[ActualDbSchema] An initializer already exists at #{initializer_path}.", :gray)
      puts "Overwrite the existing file at #{initializer_path}? [y,n] "
      answer = $stdin.gets.chomp.downcase

      if answer.start_with?("y")
        File.write(initializer_path, initializer_content)
        puts colorize("[ActualDbSchema] Initializer updated successfully at #{initializer_path}", :green)
      else
        puts colorize("[ActualDbSchema] Skipped overwriting the initializer.", :yellow)
      end
    else
      File.write(initializer_path, initializer_content)
      puts colorize("[ActualDbSchema] Initializer created successfully at #{initializer_path}", :green)
    end

    Rake::Task["actual_db_schema:install_git_hooks"].invoke
  end

  desc "Install ActualDbSchema post-checkout git hook that rolls back phantom migrations when switching branches."
  task :install_git_hooks do
    extend ActualDbSchema::OutputFormatter

    puts "Which Git hook strategy would you like to install? [1, 2, 3]"
    puts "  1) Rollback phantom migrations (db:rollback_branches)"
    puts "  2) Migrate up to latest (db:migrate)"
    puts "  3) No hook installation (skip)"
    answer = $stdin.gets.chomp

    strategy =
      case answer
      when "1" then :rollback
      when "2" then :migrate
      else
        :none
      end

    if strategy == :none
      puts colorize("[ActualDbSchema] Skipping git hook installation.", :gray)
    else
      ActualDbSchema::GitHooks.new(strategy: strategy).install_post_checkout_hook
    end
  end

  desc "Show the schema.rb diff annotated with the migrations that made the changes"
  task :diff_schema_with_migrations, %i[schema_path migrations_path] => :environment do |_, args|
    schema_path = args[:schema_path] || "./db/schema.rb"
    migrations_path = args[:migrations_path] || "db/migrate"

    schema_diff = ActualDbSchema::SchemaDiff.new(schema_path, migrations_path)
    puts schema_diff.render
  end

  desc "Delete broken migration versions from the database"
  task :delete_broken_versions, %i[versions database] => :environment do |_, args|
    extend ActualDbSchema::OutputFormatter

    if args[:versions]
      versions = args[:versions].split(" ").map(&:strip)
      versions.each do |version|
        ActualDbSchema::Migration.instance.delete(version, args[:database])
        puts colorize("[ActualDbSchema] Migration #{version} was successfully deleted.", :green)
      rescue StandardError => e
        puts colorize("[ActualDbSchema] Error deleting version #{version}: #{e.message}", :red)
      end
    elsif ActualDbSchema::Migration.instance.broken_versions.empty?
      puts colorize("[ActualDbSchema] No broken versions found.", :gray)
    else
      begin
        ActualDbSchema::Migration.instance.delete_all
        puts colorize("[ActualDbSchema] All broken versions were successfully deleted.", :green)
      rescue StandardError => e
        puts colorize("[ActualDbSchema] Error deleting all broken versions: #{e.message}", :red)
      end
    end
  end
end

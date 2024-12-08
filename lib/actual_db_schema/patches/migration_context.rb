# frozen_string_literal: true

module ActualDbSchema
  module Patches
    # Add new command to roll back the phantom migrations
    module MigrationContext
      include ActualDbSchema::OutputFormatter

      def rollback_branches(manual_mode: false)
        phantom_migrations.reverse_each do |migration|
          next unless status_up?(migration)

          show_info_for(migration) if manual_mode
          migrate(migration) if !manual_mode || user_wants_rollback?
        rescue StandardError => e
          handle_rollback_error(migration, e)
        end
      end

      def phantom_migrations
        paths = Array(migrations_paths)
        current_branch_files = Dir[*paths.flat_map { |path| "#{path}/**/[0-9]*_*.rb" }]
        current_branch_file_names = current_branch_files.map { |f| ActualDbSchema.migration_filename(f) }

        migrations.reject do |migration|
          current_branch_file_names.include?(ActualDbSchema.migration_filename(migration.filename))
        end
      end

      private

      def down_migrator_for(migration)
        if ActiveRecord::Migration.current_version < 6
          ActiveRecord::Migrator.new(:down, [migration], migration.version)
        elsif ActiveRecord::Migration.current_version < 7.1
          ActiveRecord::Migrator.new(:down, [migration], schema_migration, migration.version)
        else
          ActiveRecord::Migrator.new(:down, [migration], schema_migration, internal_metadata, migration.version)
        end
      end

      def migration_files
        paths = Array(migrations_paths)
        current_branch_files = Dir[*paths.flat_map { |path| "#{path}/**/[0-9]*_*.rb" }]
        other_branches_files = Dir["#{ActualDbSchema.migrated_folder}/**/[0-9]*_*.rb"]
        current_branch_versions = current_branch_files.map { |file| file.match(/(\d+)_/)[1] }
        filtered_other_branches_files = other_branches_files.reject do |file|
          version = file.match(/(\d+)_/)[1]
          current_branch_versions.include?(version)
        end

        current_branch_files + filtered_other_branches_files
      end

      def status_up?(migration)
        migrations_status.any? do |status, version|
          status == "up" && version.to_s == migration.version.to_s
        end
      end

      def user_wants_rollback?
        print "\nRollback this migration? [y,n] "
        answer = $stdin.gets.chomp.downcase
        answer[0] == "y"
      end

      def show_info_for(migration)
        puts colorize("\n[ActualDbSchema] A phantom migration was found and is about to be rolled back.", :gray)
        puts "Please make a decision from the options below to proceed.\n\n"
        puts "Branch: #{branch_for(migration.version.to_s)}"
        puts "Database: #{ActualDbSchema.db_config[:database]}"
        puts "Version: #{migration.version}\n\n"
        puts File.read(migration.filename)
      end

      def migrate(migration)
        message = "[ActualDbSchema] Rolling back phantom migration #{migration.version} #{migration.name} " \
            "(from branch: #{branch_for(migration.version.to_s)})"
        puts colorize(message, :gray)

        migrator = down_migrator_for(migration)
        migrator.extend(ActualDbSchema::Patches::Migrator)
        migrator.migrate
      end

      def branch_for(version)
        metadata.fetch(version, {})[:branch] || "unknown"
      end

      def metadata
        @metadata ||= ActualDbSchema::Store.instance.read
      end

      def handle_rollback_error(migration, exception)
        error_message = <<~ERROR
          Error encountered during rollback:

          #{exception.message.gsub(/^An error has occurred, all later migrations canceled:\s*/, "").strip}
        ERROR

        puts colorize(error_message, :red)
        ActualDbSchema.failed << FailedMigration.new(migration: migration, exception: exception)
      end
    end
  end
end

# frozen_string_literal: true

module ActualDbSchema
  module Patches
    # Add new command to roll back the phantom migrations
    module MigrationContext
      include ActualDbSchema::OutputFormatter

      def rollback_branches(manual_mode: false)
        schemas = multi_tenant_schemas&.call || []
        schema_count = schemas.any? ? schemas.size : 1

        rolled_back_migrations = if schemas.any?
                                   rollback_multi_tenant(schemas, manual_mode: manual_mode)
                                 else
                                   rollback_branches_for_schema(manual_mode: manual_mode)
                                 end

        delete_migrations(rolled_back_migrations, schema_count)
        rolled_back_migrations.any?
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

      def rollback_branches_for_schema(manual_mode: false, schema_name: nil, rolled_back_migrations: [])
        phantom_migrations.reverse_each do |migration|
          next unless status_up?(migration)

          show_info_for(migration, schema_name) if manual_mode
          migrate(migration, rolled_back_migrations, schema_name) if !manual_mode || user_wants_rollback?
        rescue StandardError => e
          handle_rollback_error(migration, e, schema_name)
        end

        rolled_back_migrations
      end

      def rollback_multi_tenant(schemas, manual_mode: false)
        all_rolled_back_migrations = []

        schemas.each do |schema_name|
          ActualDbSchema::MultiTenant.with_schema(schema_name) do
            rollback_branches_for_schema(manual_mode: manual_mode, schema_name: schema_name,
                                         rolled_back_migrations: all_rolled_back_migrations)
          end
        end

        all_rolled_back_migrations
      end

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

      def show_info_for(migration, schema_name = nil)
        puts colorize("\n[ActualDbSchema] A phantom migration was found and is about to be rolled back.", :gray)
        puts "Please make a decision from the options below to proceed.\n\n"
        puts "Schema: #{schema_name}" if schema_name
        puts "Branch: #{branch_for(migration.version.to_s)}"
        puts "Database: #{ActualDbSchema.db_config[:database]}"
        puts "Version: #{migration.version}\n\n"
        puts File.read(migration.filename)
      end

      def migrate(migration, rolled_back_migrations, schema_name = nil)
        migration.name = extract_class_name(migration.filename)

        message = "[ActualDbSchema]"
        message += " #{schema_name}:" if schema_name
        message += " Rolling back phantom migration #{migration.version} #{migration.name} " \
                   "(from branch: #{branch_for(migration.version.to_s)})"
        puts colorize(message, :gray)

        migrator = down_migrator_for(migration)
        migrator.extend(ActualDbSchema::Patches::Migrator)
        migrator.migrate
        rolled_back_migrations << migration
      end

      def extract_class_name(filename)
        content = File.read(filename)
        content.match(/^class\s+([A-Za-z0-9_]+)\s+</)[1]
      end

      def branch_for(version)
        metadata.fetch(version, {})[:branch] || "unknown"
      end

      def metadata
        @metadata ||= ActualDbSchema::Store.instance.read
      end

      def handle_rollback_error(migration, exception, schema_name = nil)
        error_message = <<~ERROR
          Error encountered during rollback:

          #{cleaned_exception_message(exception.message)}
        ERROR

        puts colorize(error_message, :red)
        ActualDbSchema.failed << FailedMigration.new(
          migration: migration,
          exception: exception,
          branch: branch_for(migration.version.to_s),
          schema: schema_name
        )
      end

      def cleaned_exception_message(message)
        patterns_to_remove = [
          /^An error has occurred, all later migrations canceled:\s*/,
          /^An error has occurred, this and all later migrations canceled:\s*/
        ]

        patterns_to_remove.reduce(message.strip) { |msg, pattern| msg.gsub(pattern, "").strip }
      end

      def delete_migrations(migrations, schema_count)
        migration_counts = migrations.each_with_object(Hash.new(0)) do |migration, hash|
          hash[migration.filename] += 1
        end

        migrations.uniq.each do |migration|
          count = migration_counts[migration.filename]
          File.delete(migration.filename) if count == schema_count && File.exist?(migration.filename)
        end
      end

      def multi_tenant_schemas
        ActualDbSchema.config[:multi_tenant_schemas]
      end
    end
  end
end

# frozen_string_literal: true

module ActualDbSchema
  module Patches
    # Add new command to roll back the phantom migrations
    module MigrationContext
      def rollback_branches(manual_mode: false)
        migrations.reverse_each do |migration|
          next unless status_up?(migration)

          show_info_for(migration) if manual_mode
          migrate(migration) if !manual_mode || user_wants_rollback?
        rescue StandardError => e
          handle_migration_error(e, migration)
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

        current_branch_file_names = current_branch_files.map { |f| ActualDbSchema.migration_filename(f) }
        other_branches_files.reject { |f| ActualDbSchema.migration_filename(f).in?(current_branch_file_names) }
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
        puts "\n[ActualDbSchema] A phantom migration was found and is about to be rolled back."
        puts "Please make a decision from the options below to proceed.\n\n"
        puts "Branch: #{branch_for(migration.version.to_s)}"
        puts "Database: #{db_config[:database]}"
        puts "Version: #{migration.version}\n\n"
        puts File.read(migration.filename)
      end

      def handle_migration_error(error, migration)
        raise unless error.message.include?("ActiveRecord::IrreversibleMigration")

        ActualDbSchema.failed << migration
      end

      def migrate(migration)
        migrator = down_migrator_for(migration)
        migrator.extend(ActualDbSchema::Patches::Migrator)
        migrator.migrate
      end

      def db_config
        @db_config ||= if ActiveRecord::Base.respond_to?(:connection_db_config)
                         ActiveRecord::Base.connection_db_config.configuration_hash
                       else
                         ActiveRecord::Base.connection_config
                       end
      end

      def branch_for(version)
        metadata.fetch(version, {})[:branch] || "unknown"
      end

      def metadata
        @metadata ||= ActualDbSchema::Store.instance.read
      end
    end
  end
end

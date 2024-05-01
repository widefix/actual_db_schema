# frozen_string_literal: true

module ActualDbSchema
  module Patches
    # Add new command to roll back the phantom migrations
    module MigrationContext
      def rollback_branches
        ActualDbSchema.failed = []
        migrations.reverse_each do |migration|
          migrator = down_migrator_for(migration)
          migrator.extend(ActualDbSchema::Patches::Migrator)
          migrator.migrate
        rescue StandardError => e
          raise unless e.message.include?("ActiveRecord::IrreversibleMigration")

          ActualDbSchema.failed << migration
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
    end
  end
end

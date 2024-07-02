# frozen_string_literal: true

module ActualDbSchema
  # Helper methods for loading and displaying migrations.
  module MigrationsHelper
    def load_migrations
      migrations = []

      ActualDbSchema.for_each_db_connection do
        context = ActualDbSchema.prepare_context
        indexed_migrations = context.migrations.index_by { |m| m.version.to_s }

        context.migrations_status.each do |status, version|
          migration = indexed_migrations[version]
          migrations << build_migration_struct(status, migration) if migration
        end
      end

      migrations
    end

    def load_migration(version, database)
      ActualDbSchema.for_each_db_connection do
        next unless ActualDbSchema.db_config[:database] == database

        context = ActualDbSchema.prepare_context
        migration = find_migration_in_context(context, version)
        return migration if migration
      end
      nil
    end

    private

    def build_migration_struct(status, migration)
      MigrationStruct.new(
        status: status,
        version: migration.version.to_s,
        name: migration.name,
        branch: ActualDbSchema.branch_for(ActualDbSchema.metadata, migration.version),
        database: ActualDbSchema.db_config[:database],
        filename: migration.filename
      )
    end

    def find_migration_in_context(context, version)
      migration = context.migrations.detect { |m| m.version.to_s == version }
      return unless migration

      status = context.migrations_status.detect { |_s, v| v.to_s == version }&.first || "unknown"
      build_migration_struct(status, migration)
    end
  end
end

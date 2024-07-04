# frozen_string_literal: true

module ActualDbSchema
  # The Migration class is responsible for managing and retrieving migration information
  class Migration
    include Singleton

    Migration = Struct.new(:status, :version, :name, :branch, :database, :filename, keyword_init: true)

    def self.all
      instance.all
    end

    def all
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

    private

    def build_migration_struct(status, migration)
      MigrationStruct.new(
        status: status,
        version: migration.version.to_s,
        name: migration.name,
        branch: branch_for(migration.version),
        database: ActualDbSchema.db_config[:database],
        filename: migration.filename
      )
    end

    def branch_for(version)
      metadata.fetch(version.to_s, {})[:branch] || "unknown"
    end

    def metadata
      ActualDbSchema::Store.instance.read
    end
  end
end

# frozen_string_literal: true

module ActualDbSchema
  # The Migration class is responsible for managing and retrieving migration information
  class Migration
    include Singleton

    Migration = Struct.new(:status, :version, :name, :branch, :database, :filename, :phantom, keyword_init: true)

    def self.all
      instance.all
    end

    def self.all_phantom
      instance.all_phantom
    end

    def self.find(version, database)
      instance.find(version, database)
    end

    def self.rollback(version, database)
      instance.rollback(version, database)
    end

    def self.migrate(version, database)
      instance.migrate(version, database)
    end

    def all_phantom
      migrations = []

      MigrationContext.instance.each do |context|
        indexed_migrations = context.phantom_migrations.index_by { |m| m.version.to_s }

        context.migrations_status.each do |status, version|
          migration = indexed_migrations[version]
          migrations << build_migration_struct(status, migration) if migration && status == "up"
        end
      end

      sort_migrations_desc(migrations)
    end

    def all
      migrations = []

      MigrationContext.instance.each do |context|
        indexed_migrations = context.migrations.index_by { |m| m.version.to_s }

        context.migrations_status.each do |status, version|
          migration = indexed_migrations[version]
          migrations << build_migration_struct(status, migration) if migration && status == "up"
        end
      end

      sort_migrations_desc(migrations)
    end

    def find(version, database)
      MigrationContext.instance.each do |context|
        next unless ActualDbSchema.db_config[:database] == database

        migration = find_migration_in_context(context, version)
        return migration if migration
      end
      nil
    end

    def rollback(version, database)
      MigrationContext.instance.each do |context|
        next unless ActualDbSchema.db_config[:database] == database

        if context.migrations.detect { |m| m.version.to_s == version }
          context.run(:down, version.to_i)
          break
        end
      end
    end

    def migrate(version, database)
      MigrationContext.instance.each do |context|
        next unless ActualDbSchema.db_config[:database] == database

        if context.migrations.detect { |m| m.version.to_s == version }
          context.run(:up, version.to_i)
          break
        end
      end
    end

    private

    def build_migration_struct(status, migration)
      is_phantom = migration.filename.include?("/tmp/migrated")

      Migration.new(
        status: status,
        version: migration.version.to_s,
        name: migration.name,
        branch: branch_for(migration.version),
        database: ActualDbSchema.db_config[:database],
        filename: migration.filename,
        phantom: is_phantom
      )
    end

    def sort_migrations_desc(migrations)
      migrations.sort_by { |migration| migration[:version].to_i }.reverse if migrations.any?
    end

    def find_migration_in_context(context, version)
      migration = context.migrations.detect { |m| m.version.to_s == version }
      return unless migration

      status = context.migrations_status.detect { |_s, v| v.to_s == version }&.first || "unknown"
      build_migration_struct(status, migration)
    end

    def branch_for(version)
      metadata.fetch(version.to_s, {})[:branch] || "unknown"
    end

    def metadata
      @metadata ||= {}
      @metadata[ActualDbSchema.db_config[:database]] ||= ActualDbSchema::Store.instance.read
    end
  end
end

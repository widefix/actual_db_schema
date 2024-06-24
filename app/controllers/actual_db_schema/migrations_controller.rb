# frozen_string_literal: true

module ActualDbSchema
  class MigrationsController < ActionController::Base
    def index
      @phantom_migrations = []

      ActualDbSchema.for_each_db_connection do
        context = fetch_migration_context
        context.extend(ActualDbSchema::Patches::MigrationContext)

        indexed_phantom_migrations = context.migrations.index_by { |m| m.version.to_s }

        context.migrations_status.each do |status, version|
          migration = indexed_phantom_migrations[version]
          next unless migration

          @phantom_migrations << {
            status: status,
            version: version,
            branch: branch_for(version),
            filename: migration.filename.gsub("#{Rails.root}/", "")
          }
        end
      end
    end

    private

    def fetch_migration_context
      ar_version = Gem::Version.new(ActiveRecord::VERSION::STRING)
      if ar_version >= Gem::Version.new("7.2.0") ||
         (ar_version >= Gem::Version.new("7.1.0") && ar_version.prerelease?)
        ActiveRecord::Base.connection_pool.migration_context
      else
        ActiveRecord::Base.connection.migration_context
      end
    end

    def branch_for(version)
      metadata.fetch(version.to_s, {})[:branch] || "unknown"
    end

    def metadata
      @metadata ||= ActualDbSchema::Store.instance.read
    end
  end
end

# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the list of phantom migrations for each database connection.
  class MigrationsController < ActionController::Base
    before_action :load_migrations, only: %i[index]

    def index; end

    def show
      @migration = load_migration(params[:id], params[:database])
    end

    def rollback
      version = params[:id]
      database = params[:database]

      rollback_migration(version, database)

      redirect_to migrations_path, notice: "Migration #{version} has been rolled back."
    end

    private

    def load_migrations
      @migrations = []

      ActualDbSchema.for_each_db_connection do
        context = prepare_context
        indexed_phantom_migrations = context.migrations.index_by { |m| m.version.to_s }

        context.migrations_status.each do |status, version|
          migration = indexed_phantom_migrations[version]
          next unless migration

          @migrations << build_migration_struct(status, migration)
        end
      end
    end

    def load_migration(version, database)
      ActualDbSchema.for_each_db_connection do
        next unless ActualDbSchema.db_config[:database] == database

        context = prepare_context
        migration = find_migration_in_context(context, version)
        return migration if migration
      end
      nil
    end

    def rollback_migration(version, database)
      ActualDbSchema.for_each_db_connection do
        next unless ActualDbSchema.db_config[:database] == database

        context = prepare_context
        if context.migrations.detect { |m| m.version.to_s == version }
          context.run(:down, version.to_i)
          break
        end
      end
    end

    def find_migration_in_context(context, version)
      migration = context.migrations.detect { |m| m.version.to_s == version }
      return unless migration

      status = context.migrations_status.detect { |_s, v| v.to_s == version }&.first || "unknown"
      build_migration_struct(status, migration)
    end

    def prepare_context
      context = ActualDbSchema.fetch_migration_context
      context.extend(ActualDbSchema::Patches::MigrationContext)
      context
    end

    def build_migration_struct(status, migration)
      ActualDbSchema::MigrationStruct.new(
        status,
        migration.version.to_s,
        migration.name,
        branch_for(migration.version),
        ActualDbSchema.db_config[:database],
        migration.filename
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

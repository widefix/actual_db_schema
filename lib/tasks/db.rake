# frozen_string_literal: true

return unless Rails.env.development?

require "active_record/migration"

def migrated_folder
  Rails.root.join("tmp", "migrated").tap { |folder| FileUtils.mkdir_p(folder) }
end

def migration_filename(fullpath)
  fullpath.split("/").last
end

# All patches are namespaced into this module
module ActualDbSchema
  class << self
    attr_accessor :failed
  end

  self.failed = []

  # Track migrated migrations inside the tmp folder
  module MigrationProxyPatch
    def migrate(direction)
      super(direction)
      FileUtils.copy(filename, migrated_folder.join(basename)) if direction == :up
    end
  end

  # Run only one migration that's being rolled back
  module MigratorPatch
    def runnable
      migration = migrations.first # there is only one migration, because we pass only one here
      ran?(migration) ? [migration] : []
    end
  end

  # Add new command to roll back the phantom migrations
  module MigrationContextPatch
    def rollback_branches
      migrations.each do |migration|
        migrator = down_migrator_for(migration)
        migrator.extend(ActualDbSchema::MigratorPatch)
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
      else
        ActiveRecord::Migrator.new(:down, [migration], schema_migration, migration.version)
      end
    end

    def migration_files
      paths = Array(migrations_paths)
      current_branch_files = Dir[*paths.flat_map { |path| "#{path}/**/[0-9]*_*.rb" }]
      other_branches_files = Dir["#{migrated_folder}/**/[0-9]*_*.rb"]

      current_branch_file_names = current_branch_files.map { |f| migration_filename(f) }
      other_branches_files.reject { |f| migration_filename(f).in?(current_branch_file_names) }
    end
  end
end

ActiveRecord::MigrationProxy.prepend(ActualDbSchema::MigrationProxyPatch)

namespace :db do
  desc "Rollback migrations that were run inside not a merged branch."
  task rollback_branches: :load_config do
    if ActiveRecord::Migration.current_version >= 6
      ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:rollback_branches")
    end

    context = ActiveRecord::Base.connection.migration_context
    context.extend(ActualDbSchema::MigrationContextPatch)
    context.rollback_branches
    if ActualDbSchema.failed.any?
      puts ""
      puts "[ActualDbSchema] Irreversible migrations were found from other branches. Roll them back or fix manually:"
      puts ""
      puts ActualDbSchema.failed.map { |migration| "- #{migration.filename}" }.join("\n")
      puts ""
    end
    # raise ActualDbSchema.failed.inspect
  end

  task _dump: :rollback_branches
end

# frozen_string_literal: true

require "active_record/migration"

def migrated_folder
  Rails.root.join("tmp", "migrated").tap { |folder| FileUtils.mkdir_p(folder) }
end

def migration_filename(fullpath)
  fullpath.split("/").last
end

# Track migrated migrations inside the tmp folder
module MigrationProxyPatch
  def migrate(direction)
    if direction == :up
      FileUtils.copy(filename, migrated_folder.join(basename))
    else
      FileUtils.rm(migrated_folder.join(basename))
    end
    super(direction)
  end
end

ActiveRecord::MigrationProxy.prepend(MigrationProxyPatch)

# Run only one migration that's being rolled back
module MigratorPath
  def runnable
    migration = migrations.first # there is only one migration, because we pass only one here
    ran?(migration) ? [migration] : []
  end
end

# Add new command to roll back the phantom migrations
module MigrationContextPatch
  def rollback_branches
    migrations.each do
      migrator = ActiveRecord::Migrator.new(:down, [_1], schema_migration, _1.version)
      migrator.extend(MigratorPath)
      migrator.migrate
    end
  end

  private

  def migration_files
    paths = Array(migrations_paths)
    current_branch_files = Dir[*paths.flat_map { |path| "#{path}/**/[0-9]*_*.rb" }]
    other_branches_files = Dir["#{migrated_folder}/**/[0-9]*_*.rb"]

    current_branch_file_names = current_branch_files.map { migration_filename(_1) }
    other_branches_files.reject { migration_filename(_1).in?(current_branch_file_names) }
  end
end

namespace :db do
  desc "Rollback migrations that were run inside not a merged branch."
  task rollback_branches: :load_config do
    ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:rollback_branches")

    context = ActiveRecord::Base.connection.migration_context
    context.extend(MigrationContextPatch)
    context.rollback_branches
  end

  task _dump: :rollback_branches
end

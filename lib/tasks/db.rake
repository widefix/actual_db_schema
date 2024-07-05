# frozen_string_literal: true

namespace :db do
  desc "Rollback migrations that were run inside not a merged branch."
  task rollback_branches: :load_config do
    ActualDbSchema.failed = []
    ActualDbSchema::DatabaseConnection.instance.for_each_migration_context do |context|
      ActualDbSchema::Commands::Rollback.new(context: context).call
    end
  end

  namespace :rollback_branches do
    desc "Manually rollback phantom migrations one by one"
    task manual: :load_config do
      ActualDbSchema.failed = []
      ActualDbSchema::DatabaseConnection.instance.for_each_migration_context do |context|
        ActualDbSchema::Commands::Rollback.new(manual_mode: true, context: context).call
      end
    end
  end

  desc "List all phantom migrations - non-relevant migrations that were run inside not a merged branch."
  task phantom_migrations: :load_config do
    ActualDbSchema::DatabaseConnection.instance.for_each_migration_context do |context|
      ActualDbSchema::Commands::List.new(context: context).call
    end
  end

  task "schema:dump" => :rollback_branches
end

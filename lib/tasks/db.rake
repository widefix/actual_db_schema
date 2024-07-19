# frozen_string_literal: true

namespace :db do
  desc "Rollback migrations that were run inside not a merged branch."
  task rollback_branches: :load_config do
    ActualDbSchema.failed = []
    ActualDbSchema::MigrationContext.instance.each do |context|
      ActualDbSchema::Commands::Rollback.new(context).call
    end
  end

  namespace :rollback_branches do
    desc "Manually rollback phantom migrations one by one"
    task manual: :load_config do
      ActualDbSchema.failed = []
      ActualDbSchema::MigrationContext.instance.each do |context|
        ActualDbSchema::Commands::Rollback.new(context, manual_mode: true).call
      end
    end
  end

  desc "List all phantom migrations - non-relevant migrations that were run inside not a merged branch."
  task phantom_migrations: :load_config do
    ActualDbSchema::MigrationContext.instance.each do |context|
      ActualDbSchema::Commands::List.new(context).call
    end
  end

  task "schema:dump" => :rollback_branches
end

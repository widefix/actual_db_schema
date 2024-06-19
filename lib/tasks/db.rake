# frozen_string_literal: true

namespace :db do
  desc "Rollback migrations that were run inside not a merged branch."
  task rollback_branches: :load_config do
    ActualDbSchema.failed = []
    ActualDbSchema.for_each_db_connection do
      ActualDbSchema::Commands::Rollback.new(false).call
    end
  end

  namespace :rollback_branches do
    desc "Manually rollback phantom migrations one by one"
    task manual: :load_config do
      ActualDbSchema.failed = []
      ActualDbSchema.for_each_db_connection do
        ActualDbSchema::Commands::Rollback.new(true).call
      end
    end
  end

  desc "List all phantom migrations - non-relevant migrations that were run inside not a merged branch."
  task phantom_migrations: :load_config do
    ActualDbSchema.for_each_db_connection do
      ActualDbSchema::Commands::List.new.call
    end
  end

  task "schema:dump" => :rollback_branches
end

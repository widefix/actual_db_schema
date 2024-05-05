# frozen_string_literal: true

namespace :db do
  desc "Rollback migrations that were run inside not a merged branch."
  task rollback_branches: :load_config do
    ActualDbSchema::Commands::Rollback.new.call
  end

  desc "List all phantom migrations - non-relevant migrations that were run inside not a merged branch."
  task phantom_migrations: :load_config do
    configs = ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env)
    configs.each do |db_config|
      ActiveRecord::Base.establish_connection(db_config)
      ActualDbSchema::Commands::List.new.call
    end
  end

  task _dump: :rollback_branches
end

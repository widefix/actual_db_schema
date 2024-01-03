# frozen_string_literal: true

namespace :db do
  desc "Rollback migrations that were run inside not a merged branch."
  task rollback_branches: :load_config do
    ActualDbSchema::Commands::Rollback.new.call
  end

  desc "List all phantom migrations - non-relevant migrations that were run inside not a merged branch."
  task phantom_migrations: :load_config do
    ActualDbSchema::Commands::List.new.call
  end

  task _dump: :rollback_branches
end

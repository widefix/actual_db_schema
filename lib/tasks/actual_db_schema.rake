# frozen_string_literal: true

namespace :actual_db_schema do
  desc "Install ActualDbSchema post-checkout git hook that rolls back phantom migrations when switching branches."
  task :install_git_hooks do
    ActualDbSchema::GitHooks.install_post_checkout_hook
  end
end

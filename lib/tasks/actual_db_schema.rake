# frozen_string_literal: true

namespace :actual_db_schema do
  desc "Install ActualDbSchema post-checkout git hook that rolls back phantom migrations when switching branches."
  task :install_git_hooks do
    extend ActualDbSchema::OutputFormatter

    puts "Which Git hook strategy would you like to install? [1, 2, 3]"
    puts "  1) Rollback phantom migrations (db:rollback_branches)"
    puts "  2) Migrate up to latest (db:migrate)"
    puts "  3) No hook installation (skip)"
    answer = $stdin.gets.chomp

    strategy =
      case answer
      when "1" then :rollback
      when "2" then :migrate
      else
        :none
      end

    if strategy == :none
      puts colorize("[ActualDbSchema] Skipping git hook installation.", :gray)
    else
      ActualDbSchema::GitHooks.new(strategy: strategy).install_post_checkout_hook
    end
  end
end

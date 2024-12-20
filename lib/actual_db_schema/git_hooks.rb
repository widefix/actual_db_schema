# frozen_string_literal: true

require "fileutils"

module ActualDbSchema
  # Handles the installation of a git post-checkout hook that rolls back phantom migrations when switching branches
  module GitHooks
    extend ActualDbSchema::OutputFormatter

    POST_CHECKOUT_HOOK = <<~BASH
      #!/usr/bin/env bash
      # ActualDbSchema post-checkout hook
      # This hook runs whenever you switch branches with `git checkout` to rollback phantom migrations.

      if [ -f ./bin/rails ]; then
        if [ -n "$ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED" ]; then
          GIT_HOOKS_ENABLED="$ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED"
        else
          GIT_HOOKS_ENABLED=$(./bin/rails runner "puts ActualDbSchema.config[:git_hooks_enabled]" 2>/dev/null)
        fi

        if [ "$GIT_HOOKS_ENABLED" == "true" ]; then
          ./bin/rails db:rollback_branches
        fi
      fi
    BASH

    class << self
      def install_post_checkout_hook
        return unless git_hooks_enabled?
        return unless hooks_directory_present?

        hook_path = hooks_dir.join("post-checkout")

        return unless hook_exist?(hook_path)

        File.open(hook_path, "w") { |file| file.write(POST_CHECKOUT_HOOK) }
        FileUtils.chmod("+x", hook_path)
        puts colorize("[ActualDbSchema] post-checkout git hook installed successfully at #{hook_path}", :green)
      end

      private

      def git_hooks_enabled?
        return true if ActualDbSchema.config[:git_hooks_enabled]

        puts colorize("[ActualDbSchema] Git hooks are disabled in configuration. Skipping installation.", :gray)
      end

      def hooks_directory_present?
        return true if Dir.exist?(hooks_dir)

        puts colorize("[ActualDbSchema] .git/hooks directory not found. Please ensure this is a Git repository.", :gray)
      end

      def hooks_dir
        @hooks_dir ||= Rails.root.join(".git", "hooks")
      end

      def hook_exist?(hook_path)
        return true unless File.exist?(hook_path)

        puts colorize("[ActualDbSchema] A post-checkout hook already exists at #{hook_path}.", :gray)
        puts "Overwrite the existing hook at #{hook_path}? [y,n] "
        answer = $stdin.gets.chomp.downcase
        answer[0] == "y"
      end
    end
  end
end

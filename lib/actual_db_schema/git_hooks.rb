# frozen_string_literal: true

require "fileutils"

module ActualDbSchema
  # Handles the installation of a git post-checkout hook that rolls back phantom migrations when switching branches
  class GitHooks
    include ActualDbSchema::OutputFormatter

    POST_CHECKOUT_MARKER_START = "# >>> BEGIN ACTUAL_DB_SCHEMA"
    POST_CHECKOUT_MARKER_END   = "# <<< END ACTUAL_DB_SCHEMA"

    POST_CHECKOUT_HOOK_ROLLBACK = <<~BASH
      #{POST_CHECKOUT_MARKER_START}
      # ActualDbSchema post-checkout hook (ROLLBACK)
      # Runs db:rollback_branches on branch checkout.

      # Check if this is a file checkout or creating a new branch
      if [ "$3" == "0" ] || [ "$1" == "$2" ]; then
        exit 0
      fi

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
      #{POST_CHECKOUT_MARKER_END}
    BASH

    POST_CHECKOUT_HOOK_MIGRATE = <<~BASH
      #{POST_CHECKOUT_MARKER_START}
      # ActualDbSchema post-checkout hook (MIGRATE)
      # Runs db:migrate on branch checkout.

      # Check if this is a file checkout or creating a new branch
      if [ "$3" == "0" ] || [ "$1" == "$2" ]; then
        exit 0
      fi

      if [ -f ./bin/rails ]; then
        if [ -n "$ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED" ]; then
          GIT_HOOKS_ENABLED="$ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED"
        else
          GIT_HOOKS_ENABLED=$(./bin/rails runner "puts ActualDbSchema.config[:git_hooks_enabled]" 2>/dev/null)
        fi

        if [ "$GIT_HOOKS_ENABLED" == "true" ]; then
          ./bin/rails db:migrate
        fi
      fi
      #{POST_CHECKOUT_MARKER_END}
    BASH

    def initialize(strategy: :rollback)
      @strategy = strategy
    end

    def install_post_checkout_hook
      return unless git_hooks_enabled?
      return unless hooks_directory_present?

      if File.exist?(hook_path)
        handle_existing_hook
      else
        create_new_hook
      end
    end

    private

    def hook_code
      @strategy == :migrate ? POST_CHECKOUT_HOOK_MIGRATE : POST_CHECKOUT_HOOK_ROLLBACK
    end

    def hooks_dir
      @hooks_dir ||= Rails.root.join(".git", "hooks")
    end

    def hook_path
      @hook_path ||= hooks_dir.join("post-checkout")
    end

    def git_hooks_enabled?
      return true if ActualDbSchema.config[:git_hooks_enabled]

      puts colorize("[ActualDbSchema] Git hooks are disabled in configuration. Skipping installation.", :gray)
    end

    def hooks_directory_present?
      return true if Dir.exist?(hooks_dir)

      puts colorize("[ActualDbSchema] .git/hooks directory not found. Please ensure this is a Git repository.", :gray)
    end

    def handle_existing_hook
      return update_hook if markers_exist?
      return install_hook if safe_install?

      show_manual_install_instructions
    end

    def create_new_hook
      contents = <<~BASH
        #!/usr/bin/env bash

        #{hook_code}
      BASH

      write_hook_file(contents)
      print_success
    end

    def markers_exist?
      contents = File.read(hook_path)
      contents.include?(POST_CHECKOUT_MARKER_START) && contents.include?(POST_CHECKOUT_MARKER_END)
    end

    def update_hook
      contents = File.read(hook_path)
      new_contents = replace_marker_contents(contents)

      if new_contents == contents
        message = "[ActualDbSchema] post-checkout git hook already contains the necessary code. Nothing to update."
        puts colorize(message, :gray)
      else
        write_hook_file(new_contents)
        puts colorize("[ActualDbSchema] post-checkout git hook updated successfully at #{hook_path}", :green)
      end
    end

    def replace_marker_contents(contents)
      contents.gsub(
        /#{Regexp.quote(POST_CHECKOUT_MARKER_START)}.*#{Regexp.quote(POST_CHECKOUT_MARKER_END)}/m,
        hook_code.strip
      )
    end

    def safe_install?
      puts colorize("[ActualDbSchema] A post-checkout hook already exists at #{hook_path}.", :gray)
      puts "Overwrite the existing hook at #{hook_path}? [y,n] "

      answer = $stdin.gets.chomp.downcase
      answer.start_with?("y")
    end

    def install_hook
      contents = File.read(hook_path)
      new_contents = <<~BASH
        #{contents.rstrip}

        #{hook_code}
      BASH

      write_hook_file(new_contents)
      print_success
    end

    def show_manual_install_instructions
      puts colorize("[ActualDbSchema] You can follow these steps to manually install the hook:", :yellow)
      puts <<~MSG

        1. Open the existing post-checkout hook at:
           #{hook_path}

        2. Insert the following lines into that file (preferably at the end or in a relevant section).
           Make sure you include the #{POST_CHECKOUT_MARKER_START} and #{POST_CHECKOUT_MARKER_END} lines:

        #{hook_code}

        3. Ensure the post-checkout file is executable:
           chmod +x #{hook_path}

        4. Done! Now when you switch branches, phantom migrations will be rolled back automatically (if enabled).

      MSG
    end

    def write_hook_file(contents)
      File.open(hook_path, "w") { |file| file.write(contents) }
      FileUtils.chmod("+x", hook_path)
    end

    def print_success
      puts colorize("[ActualDbSchema] post-checkout git hook installed successfully at #{hook_path}", :green)
    end
  end
end

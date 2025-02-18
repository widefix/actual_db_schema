# frozen_string_literal: true

module ActualDbSchema
  # Manages the configuration settings for the gem.
  class Configuration
    attr_accessor :enabled, :auto_rollback_disabled, :ui_enabled, :git_hooks_enabled, :multi_tenant_schemas,
                  :console_migrations_enabled, :migrated_folder

    def initialize
      @enabled = Rails.env.development?
      @auto_rollback_disabled = ENV["ACTUAL_DB_SCHEMA_AUTO_ROLLBACK_DISABLED"].present?
      @ui_enabled = Rails.env.development? || ENV["ACTUAL_DB_SCHEMA_UI_ENABLED"].present?
      @git_hooks_enabled = ENV["ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED"].present?
      @multi_tenant_schemas = nil
      @console_migrations_enabled = ENV["ACTUAL_DB_SCHEMA_CONSOLE_MIGRATIONS_ENABLED"].present?
      @migrated_folder = ENV["ACTUAL_DB_SCHEMA_MIGRATED_FOLDER"].present?
    end

    def [](key)
      public_send(key)
    end

    def []=(key, value)
      public_send("#{key}=", value)
    end

    def fetch(key, default = nil)
      if respond_to?(key)
        public_send(key)
      else
        default
      end
    end
  end
end

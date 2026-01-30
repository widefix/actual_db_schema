# frozen_string_literal: true

module ActualDbSchema
  # Manages the configuration settings for the gem.
  class Configuration
    attr_accessor :enabled, :auto_rollback_disabled, :ui_enabled, :git_hooks_enabled, :multi_tenant_schemas,
                  :console_migrations_enabled, :migrated_folder, :migrations_storage, :excluded_databases

    def initialize
      apply_defaults(default_settings)
    end

    def [](key)
      public_send(key)
    end

    def []=(key, value)
      public_send("#{key}=", value)
      return unless key.to_sym == :migrations_storage && defined?(ActualDbSchema::Store)

      ActualDbSchema::Store.instance.reset_adapter
    end

    def fetch(key, default = nil)
      if respond_to?(key)
        public_send(key)
      else
        default
      end
    end

    private

    def default_settings
      {
        enabled: Rails.env.development?,
        auto_rollback_disabled: ENV["ACTUAL_DB_SCHEMA_AUTO_ROLLBACK_DISABLED"].present?,
        ui_enabled: Rails.env.development? || ENV["ACTUAL_DB_SCHEMA_UI_ENABLED"].present?,
        git_hooks_enabled: ENV["ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED"].present?,
        multi_tenant_schemas: nil,
        console_migrations_enabled: ENV["ACTUAL_DB_SCHEMA_CONSOLE_MIGRATIONS_ENABLED"].present?,
        migrated_folder: ENV["ACTUAL_DB_SCHEMA_MIGRATED_FOLDER"].present?,
        migrations_storage: ENV.fetch("ACTUAL_DB_SCHEMA_MIGRATIONS_STORAGE", "file").to_sym,
        excluded_databases: parse_excluded_databases_env
      }
    end

    def parse_excluded_databases_env
      return [] unless ENV["ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES"].present?

      ENV["ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES"].split(",").map(&:strip).map(&:to_sym)
    end

    def apply_defaults(settings)
      settings.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
  end
end

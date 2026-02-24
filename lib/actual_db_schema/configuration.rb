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
        enabled: enabled_by_default?,
        auto_rollback_disabled: env_enabled?("ACTUAL_DB_SCHEMA_AUTO_ROLLBACK_DISABLED"),
        ui_enabled: ui_enabled_by_default?,
        git_hooks_enabled: env_enabled?("ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED"),
        multi_tenant_schemas: nil,
        console_migrations_enabled: env_enabled?("ACTUAL_DB_SCHEMA_CONSOLE_MIGRATIONS_ENABLED"),
        migrated_folder: ENV["ACTUAL_DB_SCHEMA_MIGRATED_FOLDER"].present?,
        migrations_storage: migrations_storage_from_env,
        excluded_databases: parse_excluded_databases_env
      }
    end

    def enabled_by_default?
      Rails.env.development?
    end

    def ui_enabled_by_default?
      Rails.env.development? || env_enabled?("ACTUAL_DB_SCHEMA_UI_ENABLED")
    end

    def env_enabled?(key)
      ENV[key].present?
    end

    def migrations_storage_from_env
      ENV.fetch("ACTUAL_DB_SCHEMA_MIGRATIONS_STORAGE", "file").to_sym
    end

    def parse_excluded_databases_env
      return [] unless ENV["ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES"].present?

      ENV["ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES"]
        .split(",")
        .map(&:strip)
        .reject(&:empty?)
        .map(&:to_sym)
    end

    def apply_defaults(settings)
      settings.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
  end
end

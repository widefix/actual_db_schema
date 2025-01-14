# frozen_string_literal: true

module ActualDbSchema
  # Manages the configuration settings for the gem.
  class Configuration
    attr_accessor :enabled, :auto_rollback_disabled, :ui_enabled, :git_hooks_enabled, :multi_tenant_schemas

    def initialize
      @enabled = Rails.env.development?
      @auto_rollback_disabled = ENV["ACTUAL_DB_SCHEMA_AUTO_ROLLBACK_DISABLED"].present?
      @ui_enabled = Rails.env.development? || ENV["ACTUAL_DB_SCHEMA_UI_ENABLED"].present?
      @git_hooks_enabled = ENV["ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED"].present?
      @multi_tenant_schemas = nil
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

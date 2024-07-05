# frozen_string_literal: true

require "actual_db_schema/engine"
require "active_record/migration"
require "csv"
require_relative "actual_db_schema/git"
require_relative "actual_db_schema/store"
require_relative "actual_db_schema/version"
require_relative "actual_db_schema/migration"
require_relative "actual_db_schema/migration_context"
require_relative "actual_db_schema/patches/migration_proxy"
require_relative "actual_db_schema/patches/migrator"
require_relative "actual_db_schema/patches/migration_context"

require_relative "actual_db_schema/commands/base"
require_relative "actual_db_schema/commands/rollback"
require_relative "actual_db_schema/commands/list"

# The main module definition
module ActualDbSchema
  raise NotImplementedError, "ActualDbSchema is only supported in Rails" unless defined?(Rails)

  class << self
    attr_accessor :config, :failed
  end

  self.failed = []
  self.config = {
    enabled: Rails.env.development?,
    auto_rollback_disabled: ENV["ACTUAL_DB_SCHEMA_AUTO_ROLLBACK_DISABLED"].present?,
    ui_enabled: Rails.env.development? || ENV["ACTUAL_DB_SCHEMA_UI_ENABLED"].present?
  }

  def self.migrated_folder
    migrated_folders.first
  end

  def self.migrated_folders
    return [default_migrated_folder] unless migrations_paths

    Array(migrations_paths).map do |path|
      if path.end_with?("db/migrate")
        default_migrated_folder
      else
        postfix = path.split("/").last
        Rails.root.join("tmp", "migrated_#{postfix}")
      end
    end
  end

  def self.default_migrated_folder
    Rails.root.join("tmp", "migrated")
  end

  def self.migrations_paths
    if ActiveRecord::Base.respond_to?(:connection_db_config)
      ActiveRecord::Base.connection_db_config.migrations_paths
    else
      ActiveRecord::Base.connection_config[:migrations_paths]
    end
  end

  def self.db_config
    if ActiveRecord::Base.respond_to?(:connection_db_config)
      ActiveRecord::Base.connection_db_config.configuration_hash
    else
      ActiveRecord::Base.connection_config
    end
  end

  def self.migration_filename(fullpath)
    fullpath.split("/").last
  end
end

ActiveRecord::MigrationProxy.prepend(ActualDbSchema::Patches::MigrationProxy)

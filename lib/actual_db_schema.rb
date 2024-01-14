# frozen_string_literal: true

require "active_record/migration"
require "CSV"
require_relative "actual_db_schema/store"
require_relative "actual_db_schema/version"
require_relative "actual_db_schema/patches/migration_proxy"
require_relative "actual_db_schema/patches/migrator"
require_relative "actual_db_schema/patches/migration_context"

require_relative "actual_db_schema/commands/base"
require_relative "actual_db_schema/commands/rollback"
require_relative "actual_db_schema/commands/list"

# The main module definition
module ActualDbSchema
  raise NotImplementedError, "ActualDbSchema is only supported in Rails" unless defined?(Rails)

  require "railtie"

  class << self
    attr_accessor :config, :failed
  end

  self.failed = []
  self.config = {
    enabled: Rails.env.development?
  }

  def self.migrated_folder
    Rails.root.join("tmp", "migrated").tap { |folder| FileUtils.mkdir_p(folder) }
  end

  def self.migration_filename(fullpath)
    fullpath.split("/").last
  end
end

ActiveRecord::MigrationProxy.prepend(ActualDbSchema::Patches::MigrationProxy)

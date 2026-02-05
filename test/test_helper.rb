# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Clear DATABASE_URL to prevent it from overriding the test database configuration
ENV.delete("DATABASE_URL")

require "logger"
require "rails/all"
require "actual_db_schema"
require "minitest/autorun"
require "debug"
require "rake"
require "fileutils"
require "support/test_utils"

Rails.env = "test"

class FakeApplication < Rails::Application
  def initialize
    super
    config.root = File.join(__dir__, "dummy_app")
  end
end

Rails.application = FakeApplication.new

class TestingState
  class << self
    attr_accessor :up, :down, :output
  end

  def self.reset
    self.up = []
    self.down = []
    ActualDbSchema.failed = []
    self.output = +""
  end

  def self.db_config
    adapter = ENV.fetch("DB_ADAPTER", "sqlite3")

    case adapter
    when "sqlite3"
      sqlite3_config
    when "postgresql"
      postgresql_config
    when "mysql2"
      mysql2_config
    else
      raise "Unsupported adapter: #{adapter}"
    end
  end

  def self.sqlite3_config
    {
      "primary" => {
        "adapter" => "sqlite3",
        "database" => "tmp/primary.sqlite3",
        "migrations_paths" => Rails.root.join("db", "migrate").to_s
      },
      "secondary" => {
        "adapter" => "sqlite3",
        "database" => "tmp/secondary.sqlite3",
        "migrations_paths" => Rails.root.join("db", "migrate_secondary").to_s
      }
    }
  end

  def self.postgresql_config
    {
      "primary" => {
        "adapter" => "postgresql",
        "database" => "actual_db_schema_test",
        "username" => "postgres",
        "password" => "password",
        "host" => "localhost",
        "port" => 5432,
        "migrations_paths" => Rails.root.join("db", "migrate").to_s
      },
      "secondary" => {
        "adapter" => "postgresql",
        "database" => "actual_db_schema_test_secondary",
        "username" => "postgres",
        "password" => "password",
        "host" => "localhost",
        "port" => 5432,
        "migrations_paths" => Rails.root.join("db", "migrate_secondary").to_s
      }
    }
  end

  def self.mysql2_config
    {
      "primary" => {
        "adapter" => "mysql2",
        "database" => "actual_db_schema_test",
        "username" => "root",
        "password" => "password",
        "host" => "127.0.0.1",
        "port" => "3306",
        "migrations_paths" => Rails.root.join("db", "migrate").to_s
      },
      "secondary" => {
        "adapter" => "mysql2",
        "database" => "actual_db_schema_test_secondary",
        "username" => "root",
        "password" => "password",
        "host" => "127.0.0.1",
        "port" => "3306",
        "migrations_paths" => Rails.root.join("db", "migrate_secondary").to_s
      }
    }
  end

  reset
end

ActualDbSchema.config[:enabled] = true

module Minitest
  class Test
    def before_setup
      super
      if defined?(ActualDbSchema)
        ActualDbSchema::Store.instance.reset_adapter
        ActualDbSchema.failed = []
      end
      cleanup_migrated_cache if defined?(Rails) && Rails.respond_to?(:root)
      clear_db_storage_tables if defined?(TestingState)
      ActualDbSchema.config[:migrations_storage] = :file if defined?(ActualDbSchema)
      return unless defined?(ActualDbSchema::Migration)

      ActualDbSchema::Migration.instance.instance_variable_set(:@metadata, {})
    end

    private

    def cleanup_migrated_cache
      Dir.glob(Rails.root.join("tmp", "migrated*")).each { |path| FileUtils.rm_rf(path) }
      FileUtils.rm_rf(Rails.root.join("custom", "migrated"))
    end

    def clear_db_storage_tables
      db_storage_configs.each do |config|
        ActiveRecord::Base.establish_connection(**config)
        drop_db_storage_table(ActiveRecord::Base.connection)
      rescue StandardError
        next
      end
    end

    def db_storage_configs
      db_config = TestingState.db_config
      return db_config.values if db_config.is_a?(Hash) && db_config.key?("primary")

      [db_config]
    end

    def drop_db_storage_table(conn)
      table_name = "actual_db_schema_migrations"
      if conn.adapter_name =~ /postgresql|mysql/i
        drop_db_storage_table_in_schemas(conn, table_name)
      elsif conn.table_exists?(table_name)
        conn.drop_table(table_name)
      end
    end

    def drop_db_storage_table_in_schemas(conn, table_name)
      schemas = conn.select_values(<<~SQL.squish)
        SELECT table_schema
        FROM information_schema.tables
        WHERE table_name = #{conn.quote(table_name)}
      SQL
      schemas.each do |schema|
        conn.execute("DROP TABLE IF EXISTS #{conn.quote_table_name(schema)}.#{conn.quote_table_name(table_name)}")
      end
    end
  end
end

module Kernel
  alias original_puts puts

  def puts(*args)
    TestingState.output << args.join("\n")
    original_puts(*args)
  end
end

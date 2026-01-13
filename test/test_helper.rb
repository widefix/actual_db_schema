# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "logger"
require "rails/all"
require "actual_db_schema"
require "minitest/autorun"
require "debug"
require "rake"
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

class Minitest::Test
  def before_setup
    super
    ActualDbSchema.config[:migrations_storage] = :file if defined?(ActualDbSchema)
    if defined?(ActualDbSchema::Migration)
      ActualDbSchema::Migration.instance.instance_variable_set(:@metadata, {})
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

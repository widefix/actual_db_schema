# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "rails/all"
require "actual_db_schema"
require "minitest/autorun"
require "minitest/around/spec"
require "debug"
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

  def self.db_config
    {
      primary: {
        adapter: "sqlite3",
        database: "tmp/primary.sqlite3"
      },
      secondary: {
        adapter: "sqlite3",
        database: "tmp/secondary.sqlite3",
        migrations_paths: Rails.root.join("db", "migrate_secondary").to_s
      }
    }
  end

  def self.reset
    self.up = []
    self.down = []
    self.output = +""
  end

  reset
end

ActiveRecord::Tasks::DatabaseTasks.database_configuration = { test: TestingState.db_config.fetch(:primary) }
ActiveRecord::Base.establish_connection(**TestingState.db_config.fetch(:primary))

ActualDbSchema.config[:enabled] = true

module Kernel
  alias original_puts puts

  def puts(*args)
    TestingState.output << args.join("\n")
    original_puts(*args)
  end
end

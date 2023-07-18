# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "rails/all"
require "actual_db_schema"
require "minitest/autorun"
require "debug"

class FakeApplication < Rails::Application
  def initialize
    super
    config.root = File.join(__dir__, "dummy_app")
  end
end

Rails.application = FakeApplication.new

ActiveRecord::Tasks::DatabaseTasks.database_configuration = {
  test: {
    adapter: :sqlite3,
    database: "db/test.sqlite3"
  }
}

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "db/test.sqlite3")

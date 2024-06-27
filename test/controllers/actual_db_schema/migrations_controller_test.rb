# frozen_string_literal: true

require "test_helper"
require_relative "../../../app/controllers/actual_db_schema/migrations_controller"

module ActualDbSchema
  class MigrationsControllerTest < ActionController::TestCase
    def setup
      @utils = TestUtils.new
      @migration_version = @utils.migration_timestamps.first
      @database = "primary"

      ActiveRecord::Base.configurations = { "test" => TestingState.db_config["primary"] }
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config["primary"] }
      ActiveRecord::Base.establish_connection(**TestingState.db_config["primary"])
      @utils.cleanup(TestingState.db_config)
      @utils.prepare_phantom_migrations(TestingState.db_config)

      @routes = ActualDbSchema::Engine.routes

      @controller = ActualDbSchema::MigrationsController.new
    end

    test "should get index" do
      get :index
      assert_response :success
      assert_select "h2", "Phantom Migrations"
    end
  end
end

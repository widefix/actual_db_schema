# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../app/controllers/actual_db_schema/migrations_controller"

module ActualDbSchema
  class MigrationsControllerTest < ActionController::TestCase
    def setup
      @utils = TestUtils.new
      @app = Rails.application
      routes_setup
      Rails.logger = Logger.new($stdout)
      ActionController::Base.view_paths = [File.expand_path("../../../app/views/", __dir__)]
      active_record_setup
      @utils.cleanup
      @utils.prepare_phantom_migrations
    end

    def routes_setup
      @routes = @app.routes
      Rails.application.routes.draw do
        get "/rails/migrations" => "actual_db_schema/migrations#index", as: "migrations"
        get "/rails/migration/:id" => "actual_db_schema/migrations#show", as: "migration"
        post "/rails/migration/:id/rollback" => "actual_db_schema/migrations#rollback", as: "rollback_migration"
      end
      ActualDbSchema::MigrationsController.include(@routes.url_helpers)
    end

    def active_record_setup
      ActiveRecord::Base.configurations = { "test" => TestingState.db_config["primary"] }
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config["primary"] }
      ActiveRecord::Base.establish_connection(**TestingState.db_config["primary"])
    end

    test "GET #index returns a successful response" do
      get :index
      assert_response :success
      assert_equal(2, @controller.instance_variable_get(:@migrations).count)
      assert_equal(2, @controller.instance_variable_get(:@migrations).count { |migration| migration[:status] == "up" })
      assert_equal(0, @controller.instance_variable_get(:@migrations).count do |migration|
                        migration[:status] == "down"
                      end)
    end

    test "GET #show returns a successful response" do
      get :show, params: { id: "20130906111511", database: "tmp/primary.sqlite3" }
      assert_response :success
      assert_equal "20130906111511", @controller.instance_variable_get(:@migration)[:version]
      assert_equal "up", @controller.instance_variable_get(:@migration)[:status]
      assert_equal "First", @controller.instance_variable_get(:@migration)[:name]
      assert_select "h2", text: "Migration First Details"
    end

    test "POST #rollback changes migration status to down" do
      post :rollback, params: { id: "20130906111511", database: "tmp/primary.sqlite3" }
      assert_response :redirect
      get :index
      assert_equal(1, @controller.instance_variable_get(:@migrations).count { |migration| migration[:status] == "up" })
      assert_equal(1, @controller.instance_variable_get(:@migrations).count do |migration|
                        migration[:status] == "down"
                      end)
      get :show, params: { id: "20130906111511", database: "tmp/primary.sqlite3" }
      assert_equal "down", @controller.instance_variable_get(:@migration)[:status]
    end
  end
end

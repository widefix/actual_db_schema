# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../app/controllers/actual_db_schema/migrations_controller"

module ActualDbSchema
  class MigrationsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @utils = TestUtils.new
      @app = Rails.application
      @routes = @app.routes
      Rails.logger = Logger.new($stdout)
      ActualDbSchema::MigrationsController.include(@routes.url_helpers)
      Rails.application.routes.draw do
        get "/rails/migrations" => "actual_db_schema/migrations#index"
      end
      ActionController::Base.view_paths = [File.expand_path("../../../app/views/", __dir__)]
      active_record_setup
      @utils.cleanup
    end

    def active_record_setup
      ActiveRecord::Base.configurations = { "test" => TestingState.db_config["primary"] }
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config["primary"] }
      ActiveRecord::Base.establish_connection(**TestingState.db_config["primary"])
    end

    test "GET #index route resolves to correct controller action" do
      assert_routing "/rails/migrations", controller: "actual_db_schema/migrations", action: "index"
    end

    test "GET #index returns a successful response" do
      get "/rails/migrations"
      assert_response :success
    end
  end
end

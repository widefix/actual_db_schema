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
      @utils.reset_database_yml(TestingState.db_config)
      @utils.cleanup(TestingState.db_config)
      @utils.prepare_phantom_migrations(TestingState.db_config)
    end

    def routes_setup
      @routes = @app.routes
      Rails.application.routes.draw do
        get "/rails/phantom_migrations" => "actual_db_schema/phantom_migrations#index", as: "phantom_migrations"
        get "/rails/migrations" => "actual_db_schema/migrations#index", as: "migrations"
        get "/rails/migration/:id" => "actual_db_schema/migrations#show", as: "migration"
        post "/rails/migration/:id/rollback" => "actual_db_schema/migrations#rollback", as: "rollback_migration"
        post "/rails/migration/:id/migrate" => "actual_db_schema/migrations#migrate", as: "migrate_migration"
      end
      ActualDbSchema::MigrationsController.include(@routes.url_helpers)
    end

    def active_record_setup
      ActiveRecord::Base.configurations = { "test" => TestingState.db_config }
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config }
    end

    test "GET #index returns a successful response" do
      get :index
      assert_response :success
      assert_select "table" do
        assert_select "tbody" do
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111511"
            assert_select "td", text: "FirstPrimary"
            assert_select "td", text: @utils.branch_for("20130906111511")
            assert_select "td", text: "tmp/primary.sqlite3"
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111512"
            assert_select "td", text: "SecondPrimary"
            assert_select "td", text: @utils.branch_for("20130906111512")
            assert_select "td", text: "tmp/primary.sqlite3"
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111514"
            assert_select "td", text: "FirstSecondary"
            assert_select "td", text: @utils.branch_for("20130906111514")
            assert_select "td", text: "tmp/secondary.sqlite3"
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111515"
            assert_select "td", text: "SecondSecondary"
            assert_select "td", text: @utils.branch_for("20130906111515")
            assert_select "td", text: "tmp/secondary.sqlite3"
          end
        end
      end
    end

    test "GET #show returns a successful response" do
      get :show, params: { id: "20130906111511", database: "tmp/primary.sqlite3" }
      assert_response :success
      assert_select "h2", text: "Migration FirstPrimary Details"
      assert_select "table" do
        assert_select "tr" do
          assert_select "th", text: "Status"
          assert_select "td", text: "up"
        end
        assert_select "tr" do
          assert_select "th", text: "Migration ID"
          assert_select "td", text: "20130906111511"
        end
        assert_select "tr" do
          assert_select "th", text: "Database"
          assert_select "td", text: "tmp/primary.sqlite3"
        end
        assert_select "tr" do
          assert_select "th", text: "Branch"
          assert_select "td", text: @utils.branch_for("20130906111511")
        end
      end
    end

    test "GET #show returns a 404 response if migration not found" do
      get :show, params: { id: "nil", database: "tmp/primary.sqlite3" }
      assert_response :not_found
    end

    test "POST #rollback changes migration status to down and hide migration with down status" do
      post :rollback, params: { id: "20130906111511", database: "tmp/primary.sqlite3" }
      assert_response :redirect
      get :index
      assert_select "table" do
        assert_select "tbody" do
          assert_select "tr" do |rows|
            rows.each do |row|
              assert_no_match(/down/, row.text)
            end
          end
        end
      end
      assert_select ".flash", text: "Migration 20130906111511 was successfully rolled back."
    end
  end
end

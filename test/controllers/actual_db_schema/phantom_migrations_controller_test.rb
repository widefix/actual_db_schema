# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../app/controllers/actual_db_schema/phantom_migrations_controller"

module ActualDbSchema
  class PhantomMigrationsControllerTest < ActionController::TestCase
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
        get "/rails/migrations" => "actual_db_schema/migrations#index", as: "migrations"
        get "/rails/phantom_migrations" => "actual_db_schema/phantom_migrations#index", as: "phantom_migrations"
        get "/rails/phantom_migration/:id" => "actual_db_schema/phantom_migrations#show", as: "phantom_migration"
        post "/rails/phantom_migration/:id/rollback" => "actual_db_schema/phantom_migrations#rollback",
             as: "rollback_phantom_migration"
        post "/rails/phantom_migrations/rollback_all" => "actual_db_schema/phantom_migrations#rollback_all",
             as: "rollback_all_phantom_migrations"
        post "/rails/phantom_migrations/delete" => "actual_db_schema/phantom_migrations#delete",
             as: "delete_phantom_migration"
      end
      ActualDbSchema::PhantomMigrationsController.include(@routes.url_helpers)
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
          assert_select "tr" do |rows|
            rows.each do |row|
              assert_no_match(/down/, row.text)
            end
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111511"
            assert_select "td", text: "FirstPrimary"
            assert_select "td", text: @utils.branch_for("20130906111511")
            assert_select "td", text: @utils.primary_database
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111512"
            assert_select "td", text: "SecondPrimary"
            assert_select "td", text: @utils.branch_for("20130906111512")
            assert_select "td", text: @utils.primary_database
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111514"
            assert_select "td", text: "FirstSecondary"
            assert_select "td", text: @utils.branch_for("20130906111514")
            assert_select "td", text: @utils.secondary_database
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111515"
            assert_select "td", text: "SecondSecondary"
            assert_select "td", text: @utils.branch_for("20130906111515")
            assert_select "td", text: @utils.secondary_database
          end
        end
      end
    end

    test "GET #index when all migrations is down returns a not found text" do
      @utils.run_migrations
      get :index
      assert_response :success
      assert_select "p", text: "No phantom migrations found."
    end

    test "GET #show returns a successful response" do
      get :show, params: { id: "20130906111511", database: @utils.primary_database }
      assert_response :success
      assert_select "h2", text: "Phantom Migration FirstPrimary Details"
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
          assert_select "td", text: @utils.primary_database
        end
        assert_select "tr" do
          assert_select "th", text: "Branch"
          assert_select "td", text: @utils.branch_for("20130906111511")
        end
      end
    end

    test "GET #show returns a 404 response if migration not found" do
      get :show, params: { id: "nil", database: @utils.primary_database }
      assert_response :not_found
    end

    test "POST #rollback changes migration status to down and hide migration with down status" do
      post :rollback, params: { id: "20130906111511", database: @utils.primary_database }
      assert_response :redirect
      get :index
      assert_select "table" do
        assert_select "tbody" do
          assert_select "tr" do |rows|
            rows.each do |row|
              assert_no_match(/down/, row.text)
            end
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111512"
            assert_select "td", text: "SecondPrimary"
            assert_select "td", text: @utils.branch_for("20130906111512")
          end
        end
      end
      assert_select ".flash", text: "Migration 20130906111511 was successfully rolled back."
    end

    test "POST #rollback with irreversible migration returns error message" do
      %w[primary secondary].each do |prefix|
        @utils.define_migration_file("20130906111513_irreversible_#{prefix}.rb", <<~RUBY, prefix: prefix)
          class Irreversible#{prefix.camelize} < ActiveRecord::Migration[6.0]
            def up
              TestingState.up << :irreversible_#{prefix}
            end

            def down
              raise ActiveRecord::IrreversibleMigration
            end
          end
        RUBY
      end
      @utils.prepare_phantom_migrations(TestingState.db_config)
      post :rollback, params: { id: "20130906111513", database: @utils.primary_database }
      assert_response :redirect
      get :index
      message = if ENV["DB_ADAPTER"] == "mysql2"
                  "An error has occurred, all later migrations canceled:\n\nActiveRecord::IrreversibleMigration"
                else
                  "An error has occurred, this and all later migrations canceled:\n\n" \
                  "ActiveRecord::IrreversibleMigration"
                end
      assert_select ".flash", text: message
    end

    test "POST #rollback_all changes all phantom migrations status to down and hide migration with down status" do
      post :rollback_all
      assert_response :redirect
      get :index
      assert_select "p", text: "No phantom migrations found."
    end

    test "POST #delete removes migration record" do
      version = "20130906111511"
      sql = "SELECT version FROM schema_migrations WHERE version = '#{version}'"
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])

      assert_not_nil ActiveRecord::Base.connection.select_value(sql)
      post :delete, params: { id: version, database: @utils.primary_database }
      assert_response :redirect
      get :index
      assert_select "table" do |table|
        assert_no_match "20130906111511", table.text
      end
      assert_select ".flash", text: "Migration 20130906111511 was successfully deleted."
      assert_nil ActiveRecord::Base.connection.select_value(sql)
    end
  end
end

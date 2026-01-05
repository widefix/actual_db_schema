# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../app/controllers/actual_db_schema/broken_versions_controller"

module ActualDbSchema
  class BrokenVersionsControllerDbStorageTest < ActionController::TestCase
    tests ActualDbSchema::BrokenVersionsController

    def setup
      @utils = TestUtils.new
      ActualDbSchema.config[:migrations_storage] = :db
      @app = Rails.application
      routes_setup
      Rails.logger = Logger.new($stdout)
      ActionController::Base.view_paths = [File.expand_path("../../../app/views/", __dir__)]
      active_record_setup
      @utils.reset_database_yml(TestingState.db_config)
      @utils.clear_db_storage_table(TestingState.db_config)
      @utils.cleanup(TestingState.db_config)
      @utils.prepare_phantom_migrations(TestingState.db_config)
    end

    def teardown
      @utils.clear_db_storage_table(TestingState.db_config)
      ActualDbSchema.config[:migrations_storage] = :file
    end

    def routes_setup
      @routes = @app.routes
      Rails.application.routes.draw do
        get "/rails/broken_versions" => "actual_db_schema/broken_versions#index", as: "broken_versions"
        get "/rails/migrations" => "actual_db_schema/migrations#index", as: "migrations"
        post "/rails/broken_version/:id/delete" => "actual_db_schema/broken_versions#delete",
             as: "delete_broken_version"
        post "/rails/broken_versions/delete_all" => "actual_db_schema/broken_versions#delete_all",
             as: "delete_all_broken_versions"
      end
      ActualDbSchema::BrokenVersionsController.include(@routes.url_helpers)
    end

    def active_record_setup
      ActiveRecord::Base.configurations = { "test" => TestingState.db_config }
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config }
    end

    def delete_migrations_files
      @utils.delete_migrations_files_for("tmp/migrated")
      @utils.delete_migrations_files_for("tmp/migrated_migrate_secondary")
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      ActualDbSchema::Store.instance.delete(@utils.app_file("tmp/migrated/20130906111511_first_primary.rb"))
      ActualDbSchema::Store.instance.delete(@utils.app_file("tmp/migrated/20130906111512_second_primary.rb"))
      ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
      ActualDbSchema::Store.instance.delete(@utils.app_file("tmp/migrated_migrate_secondary/20130906111514_first_secondary.rb"))
      ActualDbSchema::Store.instance.delete(@utils.app_file("tmp/migrated_migrate_secondary/20130906111515_second_secondary.rb"))
    end

    test "GET #index returns a successful response" do
      delete_migrations_files
      get :index
      assert_response :success
      assert_select "table" do
        assert_select "tbody" do
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111511"
            assert_select "td", text: @utils.branch_for("20130906111511")
            assert_select "td", text: @utils.primary_database
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111512"
            assert_select "td", text: @utils.branch_for("20130906111512")
            assert_select "td", text: @utils.primary_database
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111514"
            assert_select "td", text: @utils.branch_for("20130906111514")
            assert_select "td", text: @utils.secondary_database
          end
          assert_select "tr" do
            assert_select "td", text: "up"
            assert_select "td", text: "20130906111515"
            assert_select "td", text: @utils.branch_for("20130906111515")
            assert_select "td", text: @utils.secondary_database
          end
        end
      end
    end

    test "GET #index when there are no broken versions returns a not found text" do
      get :index
      assert_response :success
      assert_select "p", text: "No broken versions found."
    end

    test "POST #delete removes migration entry from the schema_migrations table" do
      delete_migrations_files
      version = "20130906111511"
      sql = "SELECT version FROM schema_migrations WHERE version = '#{version}'"
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      assert_not_nil ActiveRecord::Base.connection.select_value(sql)

      post :delete, params: { id: "20130906111511", database: @utils.primary_database }
      assert_response :redirect
      get :index
      assert_select "table" do |table|
        assert_no_match "20130906111511", table.text
      end
      assert_select ".flash", text: "Migration 20130906111511 was successfully deleted."
      assert_nil ActiveRecord::Base.connection.select_value(sql)
    end

    test "POST #delete_all removes all broken migration entries from the schema_migrations table" do
      delete_migrations_files
      sql = "SELECT COUNT(*) FROM schema_migrations"
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)
      ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)

      post :delete_all
      assert_response :redirect
      get :index
      assert_select "p", text: "No broken versions found."
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      assert_equal 0, ActiveRecord::Base.connection.select_value(sql)
      ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
      assert_equal 0, ActiveRecord::Base.connection.select_value(sql)
    end
  end
end

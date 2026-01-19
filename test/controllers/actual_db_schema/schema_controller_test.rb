# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../app/controllers/actual_db_schema/schema_controller"

module ActualDbSchema
  class SchemaControllerTest < ActionController::TestCase
    def setup
      @utils = TestUtils.new
      @app = Rails.application
      routes_setup
      Rails.logger = Logger.new($stdout)
      ActionController::Base.view_paths = [File.expand_path("../../../app/views/", __dir__)]
      active_record_setup
      @utils.reset_database_yml(TestingState.db_config)
      @utils.cleanup(TestingState.db_config)
      define_migrations

      ActualDbSchema::SchemaDiffHtml.define_method(:initialize) do |_schema_path, _migrations_path|
        @schema_path = "test/dummy_app/db/schema.rb"
        @migrations_path = "test/dummy_app/db/migrate"
      end
    end

    def teardown
      @utils.define_migration_file("20250212084323_drop_users.rb", <<~RUBY)
        class DropUsers < ActiveRecord::Migration[6.0]
          def change
            drop_table :users, if_exists: true
          end
        end
      RUBY
      @utils.define_migration_file("20250212084324_drop_products.rb", <<~RUBY)
        class DropProducts < ActiveRecord::Migration[6.0]
          def change
            drop_table :products, if_exists: true
          end
        end
      RUBY
      @utils.run_migrations
    end

    def routes_setup
      @routes = @app.routes
      Rails.application.routes.draw do
        get "/rails/migrations" => "actual_db_schema/migrations#index", as: "migrations"
        get "/rails/schema" => "actual_db_schema/schema#index", as: "schema"
      end
      ActualDbSchema::SchemaController.include(@routes.url_helpers)
    end

    def active_record_setup
      ActiveRecord::Base.configurations = { "test" => TestingState.db_config }
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config }
    end

    def define_migrations
      @utils.define_migration_file("20250212084321_create_users_table.rb", <<~RUBY)
        class CreateUsersTable < ActiveRecord::Migration[6.0]
          def change
            create_table :users do |t|
              t.string :name
              t.timestamps
            end
          end
        end
      RUBY
      @utils.define_migration_file("20250212084322_create_products_table.rb", <<~RUBY)
        class CreateProductsTable < ActiveRecord::Migration[6.0]
          def change
            create_table :products do |t|
              t.string :name
              t.timestamps
            end
          end
        end
      RUBY
      @utils.run_migrations

      ActualDbSchema::SchemaDiff.define_method(:old_schema_content) do
        <<~RUBY
          ActiveRecord::Schema[6.0].define(version: 20250212084322) do
            create_table "products", force: :cascade do |t|
              t.string "name"
              t.datetime "created_at", null: false
              t.datetime "updated_at", null: false
            end

            create_table "users", force: :cascade do |t|
              t.string "name"
              t.datetime "created_at", null: false
              t.datetime "updated_at", null: false
            end
          end
        RUBY
      end
    end

    test "GET #index returns a successful response" do
      file_name = "20250212084325_add_surname_to_users.rb"
      @utils.define_migration_file(file_name, <<~RUBY)
        class AddSurnameToUsers < ActiveRecord::Migration[6.0]
          def change
            add_column :users, :surname, :string
          end
        end
      RUBY
      @utils.run_migrations

      get :index
      assert_response :success
      assert_select "h2", text: "Database Schema"
      assert_select "div.schema-diff pre" do |pre|
        assert_match(/create_table "products"/, pre.text)
        assert_match(/create_table "users"/, pre.text)
        assert_match(%r{\+    t\.string "surname" // #{File.join("test/dummy_app/db/migrate", file_name)} //}, pre.text)
      end
    end

    test "GET #index with search query returns filtered results" do
      get :index, params: { table: "users" }
      assert_response :success
      assert_select "h2", text: "Database Schema"
      assert_select "div.schema-diff pre" do |pre|
        assert_match(/create_table "users"/, pre.text)
        refute_match(/create_table "products"/, pre.text)
      end
    end
  end
end

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
    end

    def teardown
      @utils.define_migration_file("20250212084323_drop_users_table.rb", <<~RUBY)
        class DropUsersTable < ActiveRecord::Migration[6.0]
          def change
            drop_table :users
          end
        end
      RUBY
      @utils.define_migration_file("20250212084324_drop_products_table.rb", <<~RUBY)
        class DropProductsTable < ActiveRecord::Migration[6.0]
          def change
            drop_table :products
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
    end

    def run_migration(file_name, content)
      @utils.define_migration_file(file_name, content)
      @utils.run_migrations
      dump_schema
    end

    def dump_schema
      return unless Rails.configuration.active_record.schema_format == :sql

      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      config = if ActiveRecord::Base.respond_to?(:connection_db_config)
                 ActiveRecord::Base.connection_db_config
               else
                 ActiveRecord::Base.configurations[Rails.env]
               end
      ActiveRecord::Tasks::DatabaseTasks.structure_dump(config, Rails.root.join("db", "structure.sql").to_s)
    end

    def define_schema_diff_html_methods_for_schema_rb
      old_schema_content = File.read("test/dummy_app/db/schema.rb")
      ActualDbSchema::SchemaDiff.define_method(:old_schema_content) { old_schema_content }
      ActualDbSchema::SchemaDiffHtml.define_method(:initialize) do |_schema_path, _migrations_path|
        @schema_path = "test/dummy_app/db/schema.rb"
        @migrations_path = "test/dummy_app/db/migrate"
      end
    end

    def define_schema_diff_html_methods_for_structure_sql
      old_schema_content = File.read("test/dummy_app/db/structure.sql")
      ActualDbSchema::SchemaDiff.define_method(:old_schema_content) { old_schema_content }
      ActualDbSchema::SchemaDiffHtml.define_method(:initialize) do |_schema_path, _migrations_path|
        @schema_path = "test/dummy_app/db/structure.sql"
        @migrations_path = "test/dummy_app/db/migrate"
      end
    end

    def add_surname_to_users_migration
      <<~RUBY
        class AddSurnameToUsers < ActiveRecord::Migration[6.0]
          def change
            add_column :users, :surname, :string
          end
        end
      RUBY
    end

    test "GET #index returns a successful response when using schema.rb" do
      define_schema_diff_html_methods_for_schema_rb
      file_name = "20250212084325_add_surname_to_users.rb"
      run_migration(file_name, add_surname_to_users_migration)
      get :index
      assert_response :success
      assert_select "h2", text: "Database Schema"
      assert_select "div.schema-diff pre" do |pre|
        assert_match(/create_table "products"/, pre.text)
        assert_match(/create_table "users"/, pre.text)
        assert_match(%r{\+    t\.string "surname" // #{File.join("test/dummy_app/db/migrate", file_name)} //}, pre.text)
      end
    end

    test "GET #index with search query returns filtered results when using schema.rb" do
      define_schema_diff_html_methods_for_schema_rb
      get :index, params: { table: "users" }
      assert_response :success
      assert_select "h2", text: "Database Schema"
      assert_select "div.schema-diff pre" do |pre|
        assert_match(/create_table "users"/, pre.text)
        refute_match(/create_table "products"/, pre.text)
      end
    end

    test "GET #index returns a successful response when using structure.sql" do
      skip unless TestingState.db_config["primary"]["adapter"] == "postgresql"

      Rails.application.configure { config.active_record.schema_format = :sql }
      dump_schema
      define_schema_diff_html_methods_for_structure_sql
      file_name = "20250212084325_add_surname_to_users.rb"
      run_migration(file_name, add_surname_to_users_migration)
      get :index
      assert_response :success
      assert_select "h2", text: "Database Schema"
      assert_select "div.schema-diff pre" do |pre|
        assert_match(/CREATE TABLE public.products/, pre.text)
        assert_match(/CREATE TABLE public.users/, pre.text)
        assert_match(
          %r{\+    surname character varying // #{File.join("test/dummy_app/db/migrate", file_name)} //}, pre.text
        )
      end
    end

    test "GET #index with search query returns filtered results when using structure.sql" do
      skip unless TestingState.db_config["primary"]["adapter"] == "postgresql"

      Rails.application.configure { config.active_record.schema_format = :sql }
      dump_schema
      define_schema_diff_html_methods_for_structure_sql
      get :index, params: { table: "users" }
      assert_response :success
      assert_select "h2", text: "Database Schema"
      assert_select "div.schema-diff pre" do |pre|
        assert_match(/CREATE TABLE public.users/, pre.text)
        refute_match(/CREATE TABLE public.products/, pre.text)
      end
    end
  end
end

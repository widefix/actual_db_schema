# frozen_string_literal: true

require "test_helper"

describe "actual_db_schema:diff_schema_with_migrations" do
  let(:utils) { TestUtils.new }

  before do
    utils.reset_database_yml(TestingState.db_config["primary"])
    ActiveRecord::Base.configurations = { "test" => TestingState.db_config["primary"] }
    ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config["primary"] }
    ActiveRecord::Base.establish_connection(**TestingState.db_config["primary"])
    utils.cleanup

    utils.define_migration_file("20250124084321_create_users.rb", <<~RUBY)
      class CreateUsers < ActiveRecord::Migration[6.0]
        def change
          create_table :users do |t|
            t.string :name
            t.string :middle_name
            t.timestamps
          end

          add_index :users, :name, name: "index_users_on_name", unique: true
        end
      end
    RUBY
    utils.define_migration_file("20250124084322_create_products.rb", <<~RUBY)
      class CreateProducts < ActiveRecord::Migration[6.0]
        def change
          create_table :products do |t|
            t.string :name
            t.decimal :price, precision: 10, scale: 2
            t.timestamps
          end
        end
      end
    RUBY
    utils.run_migrations
  end

  after do
    utils.define_migration_file("20250124084323_drop_users.rb", <<~RUBY)
      class DropUsers < ActiveRecord::Migration[6.0]
        def change
          drop_table :users
        end
      end
    RUBY
    utils.define_migration_file("20250124084324_drop_products.rb", <<~RUBY)
      class DropProducts < ActiveRecord::Migration[6.0]
        def change
          drop_table :products, if_exists: true
        end
      end
    RUBY
    utils.run_migrations
  end

  def migration_path(file_name)
    File.join("test/dummy_app/db/migrate", file_name)
  end

  def invoke_rake_task(schema_path)
    Rake::Task["actual_db_schema:diff_schema_with_migrations"].invoke(schema_path, "test/dummy_app/db/migrate")
    Rake::Task["actual_db_schema:diff_schema_with_migrations"].reenable
  end

  def run_migration(file_name, content)
    utils.define_migration_file(file_name, content)
    utils.run_migrations
    dump_schema
  end

  def dump_schema
    return unless Rails.configuration.active_record.schema_format == :sql

    config = if ActiveRecord::Base.respond_to?(:connection_db_config)
               ActiveRecord::Base.connection_db_config
             else
               ActiveRecord::Base.configurations[Rails.env]
             end
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(config, Rails.root.join("db", "structure.sql").to_s)
  end

  describe "when using schema.rb" do
    before do
      old_schema_content = File.read("test/dummy_app/db/schema.rb")
      ActualDbSchema::SchemaDiff.define_method(:old_schema_content) { old_schema_content }
    end

    it "annotates adding a column" do
      file_name = "20250124084325_add_surname_to_users.rb"
      run_migration(file_name, add_surname_to_users_migration)
      invoke_rake_task("test/dummy_app/db/schema.rb")
      assert_match(
        %r{\+    t\.string "surname" // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates removing a column" do
      file_name = "20250124084326_remove_middle_name_from_users.rb"
      run_migration(file_name, remove_middle_name_from_users_migration)
      invoke_rake_task("test/dummy_app/db/schema.rb")
      assert_match(
        %r{-    t\.string "middle_name" // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates changing a column" do
      file_name = "20250124084327_change_price_precision_in_products.rb"
      run_migration(file_name, change_price_precision_in_products_migration)
      invoke_rake_task("test/dummy_app/db/schema.rb")
      assert_match(
        %r{-    t\.decimal "price", precision: 10, scale: 2 // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{\+    t\.decimal "price", precision: 15, scale: 2 // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates renaming a column" do
      file_name = "20250124084328_rename_name_to_full_name_in_users.rb"
      run_migration(file_name, rename_name_to_full_name_in_users_migration)
      invoke_rake_task("test/dummy_app/db/schema.rb")
      assert_match(
        %r{-    t\.string "name" // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{\+    t\.string "full_name" // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates adding an index" do
      file_name = "20250124084329_add_index_on_users_middle_name.rb"
      run_migration(file_name, add_index_on_users_middle_name_migration)
      invoke_rake_task("test/dummy_app/db/schema.rb")
      assert_match(
        %r{\+    t\.index \["middle_name"\], name: "index_users_on_middle_name", unique: true // #{migration_path(file_name)} //}, # rubocop:disable Layout/LineLength
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates removing an index" do
      file_name = "20250124084330_remove_index_on_users_name.rb"
      run_migration(file_name, remove_index_on_users_name_migration)
      invoke_rake_task("test/dummy_app/db/schema.rb")
      assert_match(
        %r{-    t\.index \["name"\], name: "index_users_on_name", unique: true // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates renaming an index" do
      file_name = "20250124084331_rename_index_on_users_name.rb"
      run_migration(file_name, rename_index_on_users_name_migration)
      invoke_rake_task("test/dummy_app/db/schema.rb")
      assert_match(
        %r{-    t\.index \["name"\], name: "index_users_on_name", unique: true // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{\+    t\.index \["name"\], name: "index_users_on_user_name", unique: true // #{migration_path(file_name)} //}, # rubocop:disable Layout/LineLength
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates creating a new table" do
      file_name = "20250124084332_create_categories.rb"
      run_migration(file_name, create_categories_migration)
      invoke_rake_task("test/dummy_app/db/schema.rb")
      assert_match(
        %r{\+    create_table "categories", force: :cascade do |t| // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      run_migration("20250124084333_drop_categories.rb", drop_categories_migration)
    end

    it "annotates dropping a table" do
      file_name = "20250124084334_drop_products_table.rb"
      run_migration(file_name, drop_products_table_migration)
      invoke_rake_task("test/dummy_app/db/schema.rb")
      assert_match(
        %r{-    create_table "products", force: :cascade do |t| // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "processes phantom migrations from tmp/migrated folders" do
      file_name = "20250124084335_phantom.rb"
      run_migration(file_name, phantom_migration)
      utils.remove_app_dir(Rails.root.join("db", "migrate", file_name))
      utils.run_migrations
      invoke_rake_task("test/dummy_app/db/schema.rb")
      assert_match(
        %r{\+    t\.string "email" // #{File.join("test/dummy_app/tmp/migrated", file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end
  end

  describe "when using structure.sql" do
    before do
      skip unless TestingState.db_config["primary"]["adapter"] == "postgresql"

      Rails.application.configure { config.active_record.schema_format = :sql }
      dump_schema
      old_schema_content = File.read("test/dummy_app/db/structure.sql")
      ActualDbSchema::SchemaDiff.define_method(:old_schema_content) { old_schema_content }
    end

    after do
      Rails.application.configure { config.active_record.schema_format = :ruby }
    end

    it "annotates adding a column" do
      file_name = "20250124084325_add_surname_to_users.rb"
      run_migration(file_name, add_surname_to_users_migration)
      invoke_rake_task("test/dummy_app/db/structure.sql")
      assert_match(
        %r{\+    surname character varying // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates removing a column" do
      file_name = "20250124084326_remove_middle_name_from_users.rb"
      run_migration(file_name, remove_middle_name_from_users_migration)
      invoke_rake_task("test/dummy_app/db/structure.sql")
      assert_match(
        %r{-    middle_name character varying, // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates changing a column" do
      file_name = "20250124084327_change_price_precision_in_products.rb"
      run_migration(file_name, change_price_precision_in_products_migration)
      invoke_rake_task("test/dummy_app/db/structure.sql")
      assert_match(
        %r{-    price numeric\(10,2\), // #{migration_path(file_name)} //}, TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{\+    price numeric\(15,2\), // #{migration_path(file_name)} //}, TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates renaming a column" do
      file_name = "20250124084328_rename_name_to_full_name_in_users.rb"
      run_migration(file_name, rename_name_to_full_name_in_users_migration)
      invoke_rake_task("test/dummy_app/db/structure.sql")
      assert_match(
        %r{-    name character varying, // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{\+    full_name character varying, // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates adding an index" do
      file_name = "20250124084329_add_index_on_users_middle_name.rb"
      run_migration(file_name, add_index_on_users_middle_name_migration)
      invoke_rake_task("test/dummy_app/db/structure.sql")
      assert_match(
        %r{\+CREATE UNIQUE INDEX index_users_on_middle_name ON public.users USING btree \(middle_name\); // #{migration_path(file_name)} //}, # rubocop:disable Layout/LineLength
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates removing an index" do
      file_name = "20250124084330_remove_index_on_users_name.rb"
      run_migration(file_name, remove_index_on_users_name_migration)
      invoke_rake_task("test/dummy_app/db/structure.sql")
      assert_match(
        %r{-CREATE UNIQUE INDEX index_users_on_name ON public.users USING btree \(name\); // #{migration_path(file_name)} //}, # rubocop:disable Layout/LineLength
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates renaming an index" do
      file_name = "20250124084331_rename_index_on_users_name.rb"
      run_migration(file_name, rename_index_on_users_name_migration)
      invoke_rake_task("test/dummy_app/db/structure.sql")
      assert_match(
        %r{-CREATE UNIQUE INDEX index_users_on_name ON public.users USING btree \(name\); // #{migration_path(file_name)} //}, # rubocop:disable Layout/LineLength
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{\+CREATE UNIQUE INDEX index_users_on_user_name ON public.users USING btree \(name\); // #{migration_path(file_name)} //}, # rubocop:disable Layout/LineLength
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "annotates creating a new table" do
      file_name = "20250124084332_create_categories.rb"
      run_migration(file_name, create_categories_migration)
      invoke_rake_task("test/dummy_app/db/structure.sql")
      assert_match(
        %r{\+CREATE TABLE public.categories \( // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{\+CREATE SEQUENCE public.categories_id_seq // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{\+ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id; // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{\+ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval\('public.categories_id_seq'::regclass\); // #{migration_path(file_name)} //}, # rubocop:disable Layout/LineLength
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{\+ALTER TABLE ONLY public.categories // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      run_migration("20250124084333_drop_categories.rb", drop_categories_migration)
    end

    it "annotates dropping a table" do
      file_name = "20250124084334_drop_products_table.rb"
      run_migration(file_name, drop_products_table_migration)
      invoke_rake_task("test/dummy_app/db/structure.sql")
      assert_match(
        %r{-CREATE TABLE public.products \( // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{-CREATE SEQUENCE public.products_id_seq // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{-ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id; // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{-ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval\('public.products_id_seq'::regclass\); // #{migration_path(file_name)} //}, # rubocop:disable Layout/LineLength
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
      assert_match(
        %r{-ALTER TABLE ONLY public.products // #{migration_path(file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
    end

    it "processes phantom migrations from tmp/migrated folders" do
      file_name = "20250124084335_phantom.rb"
      run_migration(file_name, phantom_migration)
      utils.remove_app_dir(Rails.root.join("db", "migrate", file_name))
      utils.run_migrations
      dump_schema
      invoke_rake_task("test/dummy_app/db/structure.sql")
      assert_match(
        %r{\+    email character varying // #{File.join("test/dummy_app/tmp/migrated", file_name)} //},
        TestingState.output.gsub(/\e\[\d+m/, "")
      )
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

  def remove_middle_name_from_users_migration
    <<~RUBY
      class RemoveMiddleNameFromUsers < ActiveRecord::Migration[6.0]
        def change
          remove_column :users, :middle_name
        end
      end
    RUBY
  end

  def change_price_precision_in_products_migration
    <<~RUBY
      class ChangePricePrecisionInProducts < ActiveRecord::Migration[6.0]
        def change
          change_column :products, :price, :decimal, precision: 15, scale: 2
        end
      end
    RUBY
  end

  def rename_name_to_full_name_in_users_migration
    <<~RUBY
      class RenameNameToFullNameInUsers < ActiveRecord::Migration[6.0]
        def change
          rename_column :users, :name, :full_name
        end
      end
    RUBY
  end

  def add_index_on_users_middle_name_migration
    <<~RUBY
      class AddIndexOnUsersMiddleName < ActiveRecord::Migration[6.0]
        def change
          add_index :users, :middle_name, name: "index_users_on_middle_name", unique: true
        end
      end
    RUBY
  end

  def remove_index_on_users_name_migration
    <<~RUBY
      class RemoveIndexOnUsersName < ActiveRecord::Migration[6.0]
        def change
          remove_index :users, name: "index_users_on_name"
        end
      end
    RUBY
  end

  def rename_index_on_users_name_migration
    <<~RUBY
      class RenameIndexOnUsersName < ActiveRecord::Migration[6.0]
        def change
          rename_index :users, "index_users_on_name", "index_users_on_user_name"
        end
      end
    RUBY
  end

  def create_categories_migration
    <<~RUBY
      class CreateCategories < ActiveRecord::Migration[6.0]
        def change
          create_table :categories do |t|
            t.string :title
            t.timestamps
          end
        end
      end
    RUBY
  end

  def drop_categories_migration
    <<~RUBY
      class DropCategories < ActiveRecord::Migration[6.0]
        def change
          drop_table :categories
        end
      end
    RUBY
  end

  def drop_products_table_migration
    <<~RUBY
      class DropProductsTable < ActiveRecord::Migration[6.0]
        def change
          drop_table :products
        end
      end
    RUBY
  end

  def phantom_migration
    <<~RUBY
      class Phantom < ActiveRecord::Migration[6.0]
        disable_ddl_transaction!

        def up
          TestingState.up << :phantom
        end

        def down
          add_column :users, :email, :string
          raise ActiveRecord::IrreversibleMigration
        end
      end
    RUBY
  end
end

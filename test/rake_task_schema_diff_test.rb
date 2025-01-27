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

    ActualDbSchema::SchemaDiff.define_method(:old_schema_content) do
      <<~RUBY
        ActiveRecord::Schema[6.0].define(version: 20250124084322) do
          create_table "products", force: :cascade do |t|
            t.string "name"
            t.decimal "price", precision: 10, scale: 2
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end

          create_table "users", force: :cascade do |t|
            t.string "name"
            t.string "middle_name"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
            t.index ["name"], name: "index_users_on_name", unique: true
          end
        end
      RUBY
    end
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

  def invoke_rake_task
    Rake::Task["actual_db_schema:diff_schema_with_migrations"].invoke(
      "test/dummy_app/db/schema.rb", "test/dummy_app/db/migrate"
    )
    Rake::Task["actual_db_schema:diff_schema_with_migrations"].reenable
  end

  it "annotates adding a column" do
    version = "20250124084325"
    utils.define_migration_file("#{version}_add_surname_to_users.rb", <<~RUBY)
      class AddSurnameToUsers < ActiveRecord::Migration[6.0]
        def change
          add_column :users, :surname, :string
        end
      end
    RUBY

    utils.run_migrations
    invoke_rake_task
    assert_match(%r{\+    t\.string "surname" // #{version} //}, TestingState.output.gsub(/\e\[\d+m/, ""))
  end

  it "annotates removing a column" do
    version = "20250124084326"
    utils.define_migration_file("#{version}_remove_middle_name_from_users.rb", <<~RUBY)
      class RemoveMiddleNameFromUsers < ActiveRecord::Migration[6.0]
        def change
          remove_column :users, :middle_name
        end
      end
    RUBY

    utils.run_migrations
    invoke_rake_task
    assert_match(%r{-    t\.string "middle_name" // #{version} //}, TestingState.output.gsub(/\e\[\d+m/, ""))
  end

  it "annotates changing a column" do
    version = "20250124084327"
    utils.define_migration_file("#{version}_change_price_precision_in_products.rb", <<~RUBY)
      class ChangePricePrecisionInProducts < ActiveRecord::Migration[6.0]
        def change
          change_column :products, :price, :decimal, precision: 15, scale: 2
        end
      end
    RUBY

    utils.run_migrations
    invoke_rake_task
    assert_match(
      %r{-    t\.decimal "price", precision: 10, scale: 2 // #{version} //}, TestingState.output.gsub(/\e\[\d+m/, "")
    )
    assert_match(
      %r{\+    t\.decimal "price", precision: 15, scale: 2 // #{version} //}, TestingState.output.gsub(/\e\[\d+m/, "")
    )
  end

  it "annotates renaming a column" do
    version = "20250124084328"
    utils.define_migration_file("#{version}_rename_name_to_full_name_in_users.rb", <<~RUBY)
      class RenameNameToFullNameInUsers < ActiveRecord::Migration[6.0]
        def change
          rename_column :users, :name, :full_name
        end
      end
    RUBY

    utils.run_migrations
    invoke_rake_task
    assert_match(%r{-    t\.string "name" // #{version} //}, TestingState.output.gsub(/\e\[\d+m/, ""))
    assert_match(%r{\+    t\.string "full_name" // #{version} //}, TestingState.output.gsub(/\e\[\d+m/, ""))
  end

  it "annotates adding an index" do
    version = "20250124084329"
    utils.define_migration_file("#{version}_add_index_on_users_middle_name.rb", <<~RUBY)
      class AddIndexOnUsersMiddleName < ActiveRecord::Migration[6.0]
        def change
          add_index :users, :middle_name, name: "index_users_on_middle_name", unique: true
        end
      end
    RUBY

    utils.run_migrations
    invoke_rake_task
    assert_match(
      %r{\+    t\.index \["middle_name"\], name: "index_users_on_middle_name", unique: true // #{version} //},
      TestingState.output.gsub(/\e\[\d+m/, "")
    )
  end

  it "annotates removing an index" do
    version = "20250124084330"
    utils.define_migration_file("#{version}_remove_index_on_users_name.rb", <<~RUBY)
      class RemoveIndexOnUsersName < ActiveRecord::Migration[6.0]
        def change
          remove_index :users, name: "index_users_on_name"
        end
      end
    RUBY
    utils.run_migrations
    invoke_rake_task
    assert_match(
      %r{-    t\.index \["name"\], name: "index_users_on_name", unique: true // #{version} //},
      TestingState.output.gsub(/\e\[\d+m/, "")
    )
  end

  it "annotates renaming an index" do
    version = "20250124084331"
    utils.define_migration_file("#{version}_rename_index_on_users_name.rb", <<~RUBY)
      class RenameIndexOnUsersName < ActiveRecord::Migration[6.0]
        def change
          rename_index :users, "index_users_on_name", "index_users_on_user_name"
        end
      end
    RUBY
    utils.run_migrations
    invoke_rake_task
    assert_match(
      %r{-    t\.index \["name"\], name: "index_users_on_name", unique: true // #{version} //},
      TestingState.output.gsub(/\e\[\d+m/, "")
    )
    assert_match(
      %r{\+    t\.index \["name"\], name: "index_users_on_user_name", unique: true // #{version} //},
      TestingState.output.gsub(/\e\[\d+m/, "")
    )
  end

  it "annotates creating a new table" do
    version = "20250124084332"
    utils.define_migration_file("#{version}_create_categories.rb", <<~RUBY)
      class CreateCategories < ActiveRecord::Migration[6.0]
        def change
          create_table :categories do |t|
            t.string :title
            t.timestamps
          end
        end
      end
    RUBY

    utils.run_migrations
    invoke_rake_task
    assert_match(
      %r{\+    create_table "categories", force: :cascade do |t| // #{version} //},
      TestingState.output.gsub(/\e\[\d+m/, "")
    )

    utils.define_migration_file("20250124084333_drop_categories.rb", <<~RUBY)
      class DropCategories < ActiveRecord::Migration[6.0]
        def change
          drop_table :categories
        end
      end
    RUBY
    utils.run_migrations
  end

  it "annotates dropping a table" do
    version = "20250124084334"
    utils.define_migration_file("#{version}_drop_products_table.rb", <<~RUBY)
      class DropProductsTable < ActiveRecord::Migration[6.0]
        def change
          drop_table :products
        end
      end
    RUBY

    utils.run_migrations
    invoke_rake_task
    assert_match(
      %r{-    create_table "products", force: :cascade do |t| // #{version} //},
      TestingState.output.gsub(/\e\[\d+m/, "")
    )
  end
end

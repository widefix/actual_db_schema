# frozen_string_literal: true

require "test_helper"

describe "multiple databases support" do
  let(:utils) do
    TestUtils.new(migrations_path: "db/migrate_secondary", migrated_path: "tmp/migrated_migrate_secondary")
  end

  around do |block|
    original_db_config = ActiveRecord::Base.connection_db_config
    ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
    utils.cleanup
    block.call
  ensure
    ActiveRecord::Base.establish_connection(original_db_config)
  end

  describe "db:rollback_branches" do
    it "creates the tmp/migrated_migrate_secondary folder" do
      refute File.exist?(utils.app_file("tmp/migrated_migrate_secondary"))
      utils.run_migrations
      assert File.exist?(utils.app_file("tmp/migrated_migrate_secondary"))
    end

    it "migrates the migrations" do
      assert_empty utils.applied_migrations
      utils.run_migrations
      assert_equal %w[20130906111511 20130906111512], utils.applied_migrations
    end

    it "keeps migrated migrations in tmp/migrated folder" do
      utils.run_migrations
      assert_equal %w[20130906111511_first.rb 20130906111512_second.rb], utils.migrated_files
    end

    it "rolls back the migrations in the reversed order" do
      utils.prepare_phantom_migrations
      assert_empty TestingState.down
      utils.run_migrations
      assert_equal %i[second first], TestingState.down
    end

    describe "with irreversible migration" do
      before do
        utils.define_migration_file("20130906111513_irreversible.rb", <<~RUBY)
          class Irreversible < ActiveRecord::Migration[6.0]
            def up
              TestingState.up << :irreversible
            end

            def down
              raise ActiveRecord::IrreversibleMigration
            end
          end
        RUBY
      end

      it "keeps track of the irreversible migrations" do
        utils.prepare_phantom_migrations
        assert_equal %i[first second irreversible], TestingState.up
        assert_empty ActualDbSchema.failed
        utils.run_migrations
        assert_equal(%w[20130906111513_irreversible.rb], ActualDbSchema.failed.map { |m| File.basename(m.filename) })
      end
    end
  end

  describe "db:phantom_migrations" do
    it "shows the list of phantom migrations" do
      ActualDbSchema::Git.stub(:current_branch, "fix-bug") do
        utils.prepare_phantom_migrations
        Rake::Task["db:phantom_migrations"].invoke
        Rake::Task["db:phantom_migrations"].reenable
        assert_match(/ Status   Migration ID    Branch   Migration File/, TestingState.output)
        assert_match(/---------------------------------------------------/, TestingState.output)
        assert_match(
          %r{   up     20130906111511  fix-bug  tmp/migrated_migrate_secondary/20130906111511_first.rb},
          TestingState.output
        )
        assert_match(
          %r{   up     20130906111512  fix-bug  tmp/migrated_migrate_secondary/20130906111512_second.rb},
          TestingState.output
        )
      end
    end
  end
end

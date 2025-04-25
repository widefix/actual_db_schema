# frozen_string_literal: true

require "test_helper"

describe "actual_db_schema:install_git_hooks" do
  let(:utils) { TestUtils.new }
  let(:hook_path) { utils.app_file(".git/hooks/post-checkout") }

  before do
    FileUtils.mkdir_p(utils.app_file(".git/hooks"))
    Rails.application.load_tasks
    ActualDbSchema.config[:git_hooks_enabled] = true
  end

  after do
    FileUtils.rm_rf(utils.app_file(".git/hooks"))
    Rake::Task["actual_db_schema:install_git_hooks"].reenable
  end

  describe "when .git/hooks directory is missing" do
    before do
      FileUtils.rm_rf(utils.app_file(".git/hooks"))
    end

    it "does not attempt installation and shows an error message" do
      utils.simulate_input("1") do
        Rake::Task["actual_db_schema:install_git_hooks"].invoke
      end
      refute File.exist?(hook_path)
      assert_match(
        %r{\[ActualDbSchema\] .git/hooks directory not found. Please ensure this is a Git repository.},
        TestingState.output
      )
    end
  end

  describe "when user chooses rollback" do
    it "installs the rollback snippet in post-checkout" do
      refute File.exist?(hook_path)
      utils.simulate_input("1") do
        Rake::Task["actual_db_schema:install_git_hooks"].invoke
      end
      assert File.exist?(hook_path)
      contents = File.read(hook_path)
      assert_includes(contents, "db:rollback_branches")
      refute_includes(contents, "db:migrate")
    end
  end

  describe "when user chooses migrate" do
    it "installs the migrate snippet in post-checkout" do
      refute File.exist?(hook_path)
      utils.simulate_input("2") do
        Rake::Task["actual_db_schema:install_git_hooks"].invoke
      end
      assert File.exist?(hook_path)
      contents = File.read(hook_path)
      assert_includes(contents, "db:migrate")
      refute_includes(contents, "db:rollback_branches")
    end
  end

  describe "when user chooses none" do
    it "skips installing the post-checkout hook" do
      refute File.exist?(hook_path)
      utils.simulate_input("3") do
        Rake::Task["actual_db_schema:install_git_hooks"].invoke
      end
      refute File.exist?(hook_path)
      assert_match(/\[ActualDbSchema\] Skipping git hook installation\./, TestingState.output)
    end
  end

  describe "when post-checkout hook already exists" do
    before do
      File.write(hook_path, "#!/usr/bin/env bash\n# Existing content\n")
    end

    it "appends content if user decides to overwrite" do
      utils.simulate_input("1\ny") do
        Rake::Task["actual_db_schema:install_git_hooks"].invoke
      end
      contents = File.read(hook_path)
      assert_includes(contents, "db:rollback_branches")
      assert_includes(contents, "# Existing content")
    end

    it "does not change file and shows manual instructions if user declines overwrite" do
      utils.simulate_input("2\nn") do
        Rake::Task["actual_db_schema:install_git_hooks"].invoke
      end
      contents = File.read(hook_path)
      refute_includes(contents, "db:migrate")
      assert_includes(contents, "# Existing content")
      assert_match(/\[ActualDbSchema\] You can follow these steps to manually install the hook/, TestingState.output)
    end
  end

  describe "existing post-checkout hook with markers" do
    before do
      File.write(
        hook_path,
        <<~BASH
          #!/usr/bin/env bash
          echo "some existing code"

          # >>> BEGIN ACTUAL_DB_SCHEMA
          echo "old snippet"
          # <<< END ACTUAL_DB_SCHEMA
        BASH
      )
    end

    it "updates the snippet if markers exist" do
      utils.simulate_input("2") do
        Rake::Task["actual_db_schema:install_git_hooks"].invoke
      end
      contents = File.read(hook_path)
      refute_includes(contents, "old snippet")
      assert_includes(contents, "db:migrate")
      assert_includes(contents, "some existing code")
    end
  end
end

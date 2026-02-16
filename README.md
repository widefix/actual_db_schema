[![Gem Version](https://badge.fury.io/rb/actual_db_schema.svg)](https://badge.fury.io/rb/actual_db_schema)

# ActualDbSchema

**Stop database headaches when switching Git branches in Rails**

Keep your database schema perfectly synchronized across Git branches, eliminate broken tests and schema conflicts, and save wasted hours on phantom migrations.

## 🚀 What You Get

- **Zero Manual Work**: Switch branches freely - phantom migrations roll back automatically
- **No More Schema Conflicts**: Clean `schema.rb`/`structure.sql` diffs every time, no irrelevant changes
- **Error Prevention**: Eliminates `ActiveRecord::NotNullViolation` and similar errors when switching branches
- **Time Savings**: Stop hunting down which branch has the problematic migration
- **Team Productivity**: Everyone stays focused on coding, not database maintenance
- **Staging/Sandbox Sync**: Keep staging and sandbox databases aligned with your current branch code
- **Visual Management**: Web UI to view and manage migrations across all databases

<img width="3024" height="1886" alt="Visual management of Rails DB migrations with ActualDbSchema" src="https://github.com/user-attachments/assets/87cfb7b4-6380-4dad-ab18-6a0633f561b5" />

And you get all of that with **zero** changes to your workflow!

## 🎯 The Problem This Solves

**Before ActualDbSchema:**
1. Work on Branch A → Add migration → Run migration
2. Switch to Branch B → Code breaks with database errors
3. Manually find and rollback the "phantom" migration
4. Deal with irrelevant `schema.rb` diffs
5. Repeat this tedious process constantly

**After ActualDbSchema:**
1. Work on any branch → Add migrations as usual
2. Switch branches freely → Everything just works
3. Focus on building features, not fixing database issues

## 🌟 Complete Feature Set

### Core Migration Management
- **Phantom Migration Detection**: Automatically identifies migrations from other branches
- **Smart Rollback**: Rolls back phantom migrations in correct dependency order
- **Irreversible Migration Handling**: Safely handles and reports irreversible migrations
- **Multi-Database Support**: Works seamlessly with multiple database configurations
- **Schema Format Agnostic**: Supports both `schema.rb` and `structure.sql`

### Automation & Git Integration
- **Automatic Rollback on Migration**: Phantom migrations roll back when running `db:migrate`
- **Git Hook Integration**: Optional automatic rollback when switching branches
- **Zero Configuration**: Works out of the box with sensible defaults
- **Custom Migration Storage**: Configurable location for storing executed migrations

### Web Interface & Management
- **Migration Dashboard**: Visual overview of all migrations across databases
- **Phantom Migration Browser**: Easy-to-use interface for viewing phantom migrations
- **One-Click Rollback**: Rollback individual or all phantom migrations via web UI
- **Broken Version Cleanup**: Identify and remove orphaned migration records
- **Schema Diff Viewer**: Visual diff of schema changes with migration annotations

### Developer Tools
- **Console Migrations**: Run migration commands directly in Rails console
- **Schema Diff Analysis**: Annotated diffs showing which migrations caused changes
- **Migration Search & Filter**: Find specific migrations across all databases
- **Detailed Migration Info**: View migration status, branch, and database information

### Team & Environment Support
- **Multi-Tenant Compatible**: Works with apartment gem and similar multi-tenant setups
- **Environment Flexibility**: Enable/disable features per environment
- **Team Synchronization**: Keeps all team members' databases in sync
- **CI/CD Friendly**: No interference with deployment pipelines

### Manual Control Options
- **Manual Rollback Mode**: Disable automatic rollback for full manual control
- **Selective Rollback**: Choose which phantom migrations to rollback
- **Interactive Mode**: Step-by-step confirmation for each rollback operation
- **Rake Task Integration**: Full set of rake tasks for command-line management

## ⚡ Quick Start

Add to your Gemfile:

```ruby
group :development do
  gem "actual_db_schema"
end
```

Install and configure:

```sh
bundle install
rails actual_db_schema:install
```

That's it! Now just run `rails db:migrate` as usual - phantom migrations roll back automatically.

## 🔧 How It Works

This gem stores all run migrations with their code in the `tmp/migrated` folder. Whenever you perform a schema dump, it rolls back the *phantom migrations*.

The *phantom migrations* list is the difference between the migrations you've executed (in the `tmp/migrated` folder) and the current ones (in the `db/migrate` folder).

Therefore, all you do is run rails `db:migrate` in your current branch. `actual_db_schema` will ensure the DB schema is up-to-date. You'll never have an inaccurate `schema.rb` file again.

## Installation

Add this line to your application's Gemfile:

```ruby
group :development do
  gem "actual_db_schema"
end
```

And then execute:

    $ bundle install

If you cannot commit changes to the repo or Gemfile, consider the local Gemfile installation described in [this post](https://blog.widefix.com/personal-gemfile-for-development/).

Next, generate your ActualDbSchema initializer file by running:

```sh
rails actual_db_schema:install
```

This will create a `config/initializers/actual_db_schema.rb` file that lists all available configuration options, allowing you to customize them as needed. The installation process will also prompt you to install the post-checkout Git hook, which automatically rolls back phantom migrations when switching branches. If enabled, this hook will run the schema actualization rake task every time you switch branches, which can slow down branch changes. Therefore, you might not always want this automatic actualization on every switch; in that case, running `rails db:migrate` manually provides a faster, more controlled alternative.

For more details on the available configuration options, see the sections below.

## Usage

Just run `rails db:migrate` inside the current branch. It will roll back all phantom migrations for all configured databases in your `database.yml.`

> [!WARNING]
> This solution implies that all migrations are reversible. The irreversible migrations should be solved manually. At the moment, the gem ignores them. You will see warnings in the terminal for each irreversible migrations.

The gem offers the following rake tasks that can be manually run according to your preferences:
- `rails db:rollback_branches` - run it to manually rolls back phantom migrations.
- `rails db:rollback_branches:manual` - run it to manually rolls back phantom migrations one by one.
- `rails db:phantom_migrations` - displays a list of phantom migrations.

## 🎛️ Configuration Options

By default, `actual_db_schema` stores all run migrations in the `tmp/migrated` folder. However, if you want to change this location, you can configure it in two ways:

### 1. Using Environment Variable

Set the environment variable `ACTUAL_DB_SCHEMA_MIGRATED_FOLDER` to your desired folder path:

```sh
export ACTUAL_DB_SCHEMA_MIGRATED_FOLDER="custom/migrated"
```

### 2. Using Initializer
Add the following line to your initializer file (`config/initializers/actual_db_schema.rb`):

```ruby
config.migrated_folder = Rails.root.join("custom", "migrated")
```

### 3. Store migrations in the database

If you want to share executed migrations across environments (e.g., staging or sandboxes),
store them in the main database instead of the local filesystem:

```ruby
config.migrations_storage = :db
```

Or via environment variable:

```sh
export ACTUAL_DB_SCHEMA_MIGRATIONS_STORAGE="db"
```

If both are set, the initializer setting (`config.migrations_storage`) takes precedence.

## 🌐 Web Interface

Access the migration management UI at:
```
http://localhost:3000/rails/phantom_migrations
```

View and manage:
- **Migration Overview**: See all executed migrations with their status, branch, and database
- **Phantom Migrations**: Identify migrations from other branches that need rollback
- **Migration Source Code**: Browse the source code of every migration ever run (including the phantom ones)
- **One-Click Actions**: Rollback or migrate individual migrations directly from the UI
- **Broken Versions**: Detect and clean up orphaned migration records safely
- **Schema Diffs**: Visual diff of schema changes annotated with their source migrations

## UI options

By default, the UI is enabled in the development environment. If you prefer to enable the UI for another environment, you can do so in two ways:

### 1. Using Environment Variable

Set the environment variable `ACTUAL_DB_SCHEMA_UI_ENABLED` to `true`:

```sh
export ACTUAL_DB_SCHEMA_UI_ENABLED=true
```

### 2. Using Initializer
Add the following line to your initializer file (`config/initializers/actual_db_schema.rb`):

```ruby
config.ui_enabled = true
```

> With this option, the UI can be disabled for all environments or be enabled in specific ones.

## Disabling Automatic Rollback

By default, the automatic rollback of migrations is enabled. If you prefer to perform manual rollbacks, you can disable the automatic rollback in two ways:

### 1. Using Environment Variable

Set the environment variable `ACTUAL_DB_SCHEMA_AUTO_ROLLBACK_DISABLED` to `true`:

```sh
export ACTUAL_DB_SCHEMA_AUTO_ROLLBACK_DISABLED=true
```

### 2. Using Initializer
Add the following line to your initializer file (`config/initializers/actual_db_schema.rb`):

```ruby
config.auto_rollback_disabled = true
```

## Automatic Phantom Migration Rollback On Branch Switch

By default, the automatic rollback of migrations on branch switch is disabled. If you prefer to automatically rollback phantom migrations whenever you switch branches with `git checkout`, you can enable it in two ways:

### 1. Using Environment Variable

Set the environment variable `ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED` to `true`:

```sh
export ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED=true
```

### 2. Using Initializer
Add the following line to your initializer file (`config/initializers/actual_db_schema.rb`):

```ruby
config.git_hooks_enabled = true
```

### Installing the Post-Checkout Hook
After enabling Git hooks in your configuration, run the rake task to install the post-checkout hook:

```sh
rake actual_db_schema:install_git_hooks
```

This task will prompt you to choose one of the three options:

1. Rollback phantom migrations with `db:rollback_branches`
2. Migrate up to the latest schema with `db:migrate`
3. Skip installing git hook

Based on your selection, a post-checkout hook will be installed or updated in your `.git/hooks` folder.

## Excluding Databases from Processing

**For Rails 6.1+ applications using multiple databases** (especially with infrastructure databases like Solid Queue, Solid Cable, or Solid Cache), you can exclude specific databases from ActualDbSchema's processing to prevent connection conflicts.

### Why You Might Need This

Modern Rails applications often use the `connects_to` pattern for infrastructure databases. These databases maintain their own isolated connection pools, and ActualDbSchema's global connection switching can interfere with active queries. This is particularly common with:

- **Solid Queue** (Rails 8 default job backend)
- **Solid Cable** (WebSocket connections)
- **Solid Cache** (caching infrastructure)

### Method 1: Using `excluded_databases` Configuration

Explicitly exclude databases by name in your initializer:

```ruby
# config/initializers/actual_db_schema.rb
ActualDbSchema.configure do |config|
  config.excluded_databases = [:queue, :cable, :cache]
end
```

### Method 2: Using Environment Variable

Set the environment variable `ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES` with a comma-separated list:

```sh
export ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES="queue,cable,cache"
```

**Note:** If both the environment variable and the configuration setting in the initializer are provided, the configuration setting takes precedence as it's applied after the default settings are loaded.

## Multi-Tenancy Support

If your application leverages multiple schemas for multi-tenancy — such as those implemented by the [apartment](https://github.com/influitive/apartment) gem or similar solutions — you can configure ActualDbSchema to handle migrations across all schemas. To do so, add the following configuration to your initializer file (`config/initializers/actual_db_schema.rb`):

```ruby
config.multi_tenant_schemas = -> { # list of all active schemas }
```

### Example:

```ruby
config.multi_tenant_schemas = -> { ["public", "tenant1", "tenant2"] }
```

## Schema Diff with Migration Annotations

If `schema.rb` generates a diff, it can be helpful to find out which migrations caused the changes. This helps you decide whether to resolve the diff on your own or discuss it with your teammates to determine the next steps. The `diff_schema_with_migrations` Rake task generates a diff of the `schema.rb` file, annotated with the migrations responsible for each change. This makes it easier to trace which migration introduced a specific schema modification, enabling faster and more informed decision-making regarding how to handle the diff.

By default, the task uses `db/schema.rb` and `db/migrate` as the schema and migrations paths. You can also provide custom paths as arguments.

Alternatively, if you use Web UI, you can see this diff at `http://localhost:3000/rails/schema`. This way is often more convenient than running the Rake task manually.

### Usage

Run the task with default paths:
```sh
rake actual_db_schema:diff_schema_with_migrations
```

Run the task with custom paths:
```sh
rake actual_db_schema:diff_schema_with_migrations[path/to/custom_schema.rb, path/to/custom_migrations]
```

## Console Migrations

Sometimes, it's necessary to modify the database without creating migration files. This can be useful for fixing a corrupted schema, conducting experiments (such as adding and removing indexes), or quickly adjusting the schema in development. This gem allows you to run the same commands used in migrations directly in the Rails console.

By default, Console Migrations is disabled. You can enable it in two ways:

### 1. Using Environment Variable

Set the environment variable `ACTUAL_DB_SCHEMA_CONSOLE_MIGRATIONS_ENABLED` to `true`:

```sh
export ACTUAL_DB_SCHEMA_CONSOLE_MIGRATIONS_ENABLED=true
```

### 2. Using Initializer

Add the following line to your initializer file (`config/initializers/actual_db_schema.rb`):

```ruby
config.console_migrations_enabled = true
```

### Usage

Once enabled, you can run migration commands directly in the Rails console:

```ruby
# Create a new table
create_table :posts do |t|
  t.string :title
end

# Add a column
add_column :users, :age, :integer

# Remove an index
remove_index :users, :email

# Rename a column
rename_column :users, :username, :handle
```

## Delete Broken Migrations

A migration is considered broken if it has been migrated in the database but the corresponding migration file is missing. This functionality allows you to safely delete these broken versions from the database to keep it clean.

You can delete broken migrations using either of the following methods:

### 1. Using the UI

Navigate to the following URL in your web browser:
```
http://localhost:3000/rails/broken_versions
```

This page lists all broken versions and provides an option to delete them.

### 2. Using a Rake Task

To delete all broken migrations, run:
```sh
rake actual_db_schema:delete_broken_versions
```

To delete specific migrations, pass the migration version(s) and optionally a database:
```sh
rake actual_db_schema:delete_broken_versions[<version>, <version>]
```

- `<version>` – The migration version(s) to delete (space-separated if multiple).
- `<database>` (optional) – Specify a database if using multiple databases.

#### Examples:

```sh
# Delete all broken migrations
rake actual_db_schema:delete_broken_versions

# Delete specific migrations
rake actual_db_schema:delete_broken_versions["20250224103352 20250224103358"]

# Delete specific migrations from a specific database
rake actual_db_schema:delete_broken_versions["20250224103352 20250224103358", "primary"]
```

## 🏗️ Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

To release a new version do the following in the order:

- update the version number in `version.rb`;
- update the CHANGELOG;
- `bundle install` to update `Gemfile.lock`;
- make the commit and push;
- run `bundle exec rake release`. This will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org);
- [announce the new release on GitHub](https://github.com/widefix/actual_db_schema/releases);
- close the milestone on GitHub.

### Running Tests with Specific Rails Versions

The following versions can be specifically tested using Appraisal
- 6.0
- 6.1
- 7.0
- 7.1
- edge

To run tests with a specific version of Rails using Appraisal:
- Run all tests with Rails 6.0:
  ```sh
  bundle exec appraisal rails.6.0 rake test
  ```
- Run tests for a specific file:
  ```sh
  bundle exec appraisal rails.6.0 rake test TEST=test/rake_task_test.rb
  ```
- Run a specific test:
  ```sh
  bundle exec appraisal rails.6.0 rake test TEST=test/rake_task_test.rb TESTOPTS="--name=/db::db:rollback_branches#test_0003_keeps/"
  ```

By default, `rake test` runs tests using `SQLite3`. To explicitly run tests with `SQLite3`, `PostgreSQL`, or `MySQL`, you can use the following tasks:
- Run tests with `SQLite3`:
  ```sh
  bundle exec rake test:sqlite3
  ```
- Run tests with `PostgreSQL` (requires Docker):
  ```sh
  bundle exec rake test:postgresql
  ```
- Run tests with `MySQL` (requires Docker):
  ```sh
  bundle exec rake test:mysql2
  ```
- Run tests for all supported adapters:
  ```sh
  bundle exec rake test:all
  ```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/widefix/actual_db_schema. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/widefix/actual_db_schema/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActualDbSchema project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/widefix/actual_db_schema/blob/master/CODE_OF_CONDUCT.md).

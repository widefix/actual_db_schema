[![Gem Version](https://badge.fury.io/rb/actual_db_schema.svg)](https://badge.fury.io/rb/actual_db_schema)

# ActualDbSchema: Keep Rails Databases in Sync with Git Branches

**Manage stale migrations, fix database drift, and understand schema changes in Rails.**

`actual_db_schema` keeps your database aligned with the migrations on your current Git branch. It tracks executed migration source code and rolls back **phantom migrations** left behind by other branches. It also provides a web dashboard, annotated schema diffs, migration history, and manual cleanup tools for development, staging, and sandbox environments.

## Problems ActualDbSchema Solves

### Database errors and failing tests after switching branches

Switching Git branches changes your code and migration files, but does not undo migrations already applied to your database. A column, table, index, or constraint from another branch can break the application or its tests. For example, an extra `NOT NULL` column can cause `ActiveRecord::NotNullViolation` when the current branch inserts a record.

ActualDbSchema rolls back tracked migrations missing from the current branch, removing their database changes when their reversals succeed.

### Manual rollback work when moving between feature branches

Without a stored copy of a migration, you may need to find the branch that introduced it, check it out, roll it back, and return to your work. These stale migrations are called **phantom migrations**: they have been applied to the database, but their files are absent from the current branch.

The gem saves migration source code and branch metadata so it can identify and roll back phantom migrations without checking out their original branch. Cleanup runs as part of the schema dump triggered by `rails db:migrate`. An optional [post-checkout Git hook](#automatic-phantom-migration-rollback-on-branch-switch) runs cleanup when you switch branches. You can also inspect and roll back migrations manually through rake tasks or the web UI.

### Unwanted schema.rb diffs and schema conflicts in Git

**Why does `schema.rb` keep changing after `db:migrate`, even when you have not changed a migration?** Rails dumps your database's actual structure, including leftover tables, columns, and indexes from other branches. Those changes pollute `db/schema.rb` or `db/structure.sql` and can lead to unrelated pull request changes and Git merge conflicts.

ActualDbSchema rolls back tracked phantom migrations before the schema dump, preventing their leftover changes from appearing in the generated file. Legitimate schema changes from the current branch still appear in the diff. Both schema formats are supported.

### Rebuilding the entire database to clean up stale migrations

Resetting a development database and replaying migrations can take time and discard local data. ActualDbSchema targets tracked phantom migrations instead of requiring a full database reset. Each rollback still executes the migration's reversal and can remove data in affected tables or columns.

### Difficulty tracing a schema change to its migration

When a schema diff contains unexpected changes, it can be hard to tell which migration introduced them. The [annotated schema diff](#schema-diff-with-migration-annotations) associates changes with migration source files, available through a rake task or the web UI. This helps you investigate a diff before deciding how to resolve it.

### Missing visibility into migration history and database state

The [web dashboard](#-web-interface) lets you inspect migration status, source code, branch metadata, and phantom migrations across configured databases. It supports individual migration actions and remains accessible when pending migrations would otherwise block Rails requests.

### Orphaned migration versions with missing source files

Your database can contain migration version records whose source files are no longer available. The [broken migration cleanup tools](#delete-broken-migrations) identify and delete these orphaned records through the UI or a rake task. Deleting a version record does **not** reverse its database changes; use phantom migration rollback when stored source code is available.

### Database drift across multiple databases, tenants, and shared environments

Branch-specific migrations can leave several databases or tenant schemas out of sync, not just the primary development database. ActualDbSchema processes configured databases, supports a configurable list of [tenant schemas](#multi-tenancy-support), and lets you [exclude infrastructure databases](#excluding-databases-from-processing).

For staging or sandbox environments, optional [database-backed migration storage](#3-store-migrations-in-the-database) retains executed migration sources in the database rather than relying on one machine's local files. Features can be enabled per environment.

### Friction when experimenting with schema changes in the Rails console

The optional [console migrations](#console-migrations) feature exposes migration methods such as `add_column`, `add_index`, and `create_table` directly in the Rails console. This helps with local schema experiments and manual repairs; it does not create a migration file for you.

## Example: Switch Branches Without Leaving Phantom Migrations Behind

Suppose a feature branch adds a required `users.nickname` column. After switching to `main`, which has no such migration, inserts may fail because the application does not populate that column. The next schema dump can also add the unrelated column to `schema.rb`.

With `actual_db_schema` installed ([Quick Start](#-quick-start)), keep using your normal workflow:

```sh
git switch main
bundle exec rails db:migrate
```

The gem uses its stored migration source to roll back the phantom migration before Rails dumps the schema. When the rollback succeeds, the extra column is removed, fixing both the stale constraint and its unwanted schema diff.

## Scope and Rollback Requirements

The gem needs a stored copy of a migration to roll it back, so install it before running migrations you want it to track. Irreversible migrations and rollbacks that depend on unavailable branch code require manual intervention; failed rollbacks are reported. Phantom migrations are rolled back in reverse migration order.

ActualDbSchema does not detect edits to an already-applied migration that remains on the current branch. Its schema cleanup targets phantom migrations; it does not sort schema columns or resolve every Git merge conflict.

## Video Demo

[Watch the ActualDbSchema video demo](docs/actual_db_schema_h264.mp4)

<img width="3024" height="1886" alt="ActualDbSchema Rails migration dashboard showing migration history and database management" src="https://github.com/user-attachments/assets/87cfb7b4-6380-4dad-ab18-6a0633f561b5" />

## 🌟 Complete Feature Set

### Core Migration Management
- **Phantom Migration Detection**: Automatically identifies migrations from other branches
- **Smart Rollback**: Rolls back phantom migrations in reverse migration order
- **Rollback Failure Reporting**: Reports irreversible migrations and other rollback failures for manual resolution
- **Multi-Database Support**: Processes multiple database configurations with configurable exclusions
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
- **Shared Migration Storage**: Optional database storage retains migration sources across environments
- **Rollback Instrumentation**: Emits notifications for successful rollbacks and provides optional persisted statistics

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

This gem stores migrations executed while it is installed, including their source code, in the `tmp/migrated` folder by default. [Database storage](#3-store-migrations-in-the-database) is also available. Before the Rails `db:schema:dump` task runs, it attempts to roll back the *phantom migrations*.

The *phantom migrations* list is the difference between the migrations you've executed (in the `tmp/migrated` folder) and the current ones (in the `db/migrate` folder).

Run `rails db:migrate` in your current branch as usual. With automatic rollback enabled (the default), `actual_db_schema` rolls back tracked phantom migrations in reverse migration order before the schema dump, removing their leftover schema changes when the rollbacks succeed.

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

## Rollback Instrumentation

ActualDbSchema emits an `ActiveSupport::Notifications` event for each successful phantom rollback:

- Event name: `rollback_migration.actual_db_schema`
- Event is always emitted when a phantom rollback succeeds

### Event payload

| Field | Description |
|-------|-------------|
| `version` | Migration version that was rolled back |
| `name` | Migration class name |
| `database` | Current database name from Active Record config |
| `schema` | Tenant schema name (or `nil` for default schema) |
| `branch` | Branch associated with the migration metadata |
| `manual_mode` | Whether rollback was run in manual mode |

### Subscribing to rollback events

You can subscribe to rollback events in your initializer to track statistics or perform custom actions:

```ruby
# config/initializers/actual_db_schema.rb
ActiveSupport::Notifications.subscribe(ActualDbSchema::Instrumentation::ROLLBACK_EVENT) do |_name, _start, _finish, _id, payload|
  ActualDbSchema::RollbackStatsRepository.record(payload)
end
```

The `RollbackStatsRepository` persists rollback events to a database table (`actual_db_schema_rollback_events`) that is automatically excluded from schema dumps.

Read aggregated stats at runtime:

```ruby
ActualDbSchema::RollbackStatsRepository.stats
# => { total: 3, by_database: { "primary" => 3 }, by_schema: { "default" => 3 }, by_branch: { "main" => 3 } }

ActualDbSchema::RollbackStatsRepository.total_rollbacks
# => 3

ActualDbSchema::RollbackStatsRepository.reset!
# Clears all recorded stats
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

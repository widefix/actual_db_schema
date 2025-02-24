[![Gem Version](https://badge.fury.io/rb/actual_db_schema.svg)](https://badge.fury.io/rb/actual_db_schema)

# ActualDbSchema

Does switching between branches in your Rails app mess up the DB schema?

Keep the DB schema actual across branches in your Rails project. Just install `actual_db_schema` gem and run `db:migrate` in branches as usual. It automatically rolls back the *phantom migrations* (non-relevant to the current branch). No additional steps are needed. It works with both `schema.rb` and `structure.sql`.

## Why ActualDbSchema

Still not clear why it's needed? To grasp the purpose of this gem and the issue it addresses, review the problem definition outlined below.

### The problem definition

Imagine you're working on **branch A**. You add a not-null column to a database table with a migration. You run the migration. Then you switch to **branch B**. The code in **branch B** isn't aware of this newly added field. When it tries to write data to the table, it fails with an error `null value provided for non-null field`. Why? The existing code is writing a null value into the column with a not-null constraint.

Here's an example of this error:

    ActiveRecord::NotNullViolation:
      PG::NotNullViolation: ERROR:  null value in column "log" of relation "check_results" violates not-null constraint
      DETAIL:  Failing row contains (8, 46, success, 2022-10-16 21:47:21.07212, 2022-10-16 21:47:21.07212, null).

Furthermore, the `db:migrate` task on **branch B** generates an irrelevant diff on the `schema.rb` file, reflecting the new column added in **branch A**.

To fix this, you need to switch back to **branch A**, find the migration that added the problematic field, and roll it back. We'll call it a *phantom migration*. It's a pain, especially if you have a lot of branches in your project because you have to remember which branch the *phantom migration* is in and then manually roll it back.

With `actual_db_schema` gem you don't need to care about that anymore. It saves you time by handling all this dirty work behind the scenes automatically.

### How it solves the issue

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
rake actual_db_schema:install
```

This will create a `config/initializers/actual_db_schema.rb` file with all the available configuration options so you can adjust them as needed. It will also prompt you to install the post-checkout Git hook for automatic phantom migration rollback when switching branches.

For more details on the available configuration options, see the sections below.

## Usage

Just run `rails db:migrate` inside the current branch. It will roll back all phantom migrations for all configured databases in your `database.yml.`

> [!WARNING]
> This solution implies that all migrations are reversible. The irreversible migrations should be solved manually. At the moment, the gem ignores them. You will see warnings in the terminal for each irreversible migrations.

The gem offers the following rake tasks that can be manually run according to your preferences:
- `rails db:rollback_branches` - run it to manually rolls back phantom migrations.
- `rails db:rollback_branches:manual` - run it to manually rolls back phantom migrations one by one.
- `rails db:phantom_migrations` - displays a list of phantom migrations.

## Migrated Folder Configuration

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

## Accessing the UI

The UI for managing migrations is enabled automatically. To access the UI, simply navigate to the following URL in your web browser:
```
http://localhost:3000/rails/phantom_migrations
```
This page displays a list of phantom migrations for each database connection and provides options to view details and rollback them.

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

## Development

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

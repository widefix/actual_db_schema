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

## Usage

Just run `rails db:migrate` inside the current branch. It will roll back all phantom migrations for all configured databases in your `database.yml.`

> [!WARNING]
> This solution implies that all migrations are reversible. The irreversible migrations should be solved manually. At the moment, the gem ignores them. You will see warnings in the terminal for each irreversible migrations.

The gem offers the following rake tasks that can be manually run according to your preferences:
- `rails db:rollback_branches` - run it to manually rolls back phantom migrations.
- `rails db:rollback_branches:manual` - run it to manually rolls back phantom migrations one by one.
- `rails db:phantom_migrations` - displays a list of phantom migrations.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

To release a new version do the following in the order:

- update the version number in `version.rb`;
- update the CHANGELOG;
- `bundle install` to update `Gemfile.lock`;
- make the commit and push;
- run `bundle exec rake release`. This will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

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
- Run tests for a specific file:
  ```sh
  bundle exec appraisal rails.6.0 rake test TEST=test/rake_task_test.rb
- Run a specific test:
  ```sh
  bundle exec appraisal rails.6.0 rake test TEST=test/rake_task_test.rb TESTOPTS="--name=/db::db:rollback_branches#test_0003_keeps/"

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/widefix/actual_db_schema. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/widefix/actual_db_schema/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActualDbSchema project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/widefix/actual_db_schema/blob/master/CODE_OF_CONDUCT.md).

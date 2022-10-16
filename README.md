# ActualDbSchema

Keep Rails DB schema consistent while switching between branches with no additional actions.

## Installation

Add this line to your application's Gemfile:

```ruby
group :development do
  gem "actual_db_schema"
end
```

And then execute:

    $ bundle install

## Usage

TL;TR: Just run `rails db:migrate` inside the current branch.

In **branch A** I add a mandatory (not null) field into DB via migration and run it.
Then I switch to another **branch B**. This branch's code is not aware of that field.
As the result, the code is failing with an error "null value provided for non-null field".
Moreover, a DB rake task generates a diff on `schema.rb` that's not relevant to this branch.
I can switch to **branch A** and roll back the migration, but I need to remember that branch or waste time on it.

Some example of this error:

     ActiveRecord::NotNullViolation:
       PG::NotNullViolation: ERROR:  null value in column "log" of relation "check_results" violates not-null constraint
       DETAIL:  Failing row contains (8, 46, success, 2022-10-16 21:47:21.07212, 2022-10-16 21:47:21.07212, null).

This gem saves all run migrations inside `tmp/migrations` folder.
Every run of schema dump (that's a dependency of `db:migrate` task as well) rolls back the "unknown" for the current branch migrations
looking into the `tmp/migrations` folder.

Using this gem you need to run `rails db:migrate` in the current branch and it will actualize the DB schema.
You will never have wrongly generated `schema.rb`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/widefix/actual_db_schema. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/widefix/actual_db_schema/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActualDbSchema project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/widefix/actual_db_schema/blob/master/CODE_OF_CONDUCT.md).

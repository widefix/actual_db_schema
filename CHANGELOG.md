## [0.7.6] - 2024-07-05
- Added UI
- Added environment variable `ACTUAL_DB_SCHEMA_UI_ENABLED` to enable/disable the UI in specific environments
- Added configuration option `ActualDbSchema.config[:ui_enabled]` to enable/disable the UI in specific environments

## [0.7.5] - 2024-06-20
- Added db:rollback_migrations:manual task to manually rolls back phantom migrations one by one

## [0.7.4] - 2024-06-06
- Rails 7.2 support added
- Rails 6.0 support added

## [0.7.3] - 2024-04-06
- add multipe databases support

## [0.7.2] - 2024-03-30
- update title and description in Rubygems

## [0.7.1] - 2024-03-19

- add csv as a dependency since Ruby 3.3 has removed it from the standard library

## [0.7.0] - 2024-01-18

- db:phantom_migrations displays the branch in which the phantion migration was run

## [0.6.0] - 2024-01-03

- Added db:phantom_migrations task to display phantom migrations
- Updated README

## [0.5.0] - 2023-11-06

- Rails 7.1 support added

## [0.4.0] - 2023-07-05

- rollback migrations in the reversed order

## [0.3.0] - 2023-01-23

- add Rails 6 and older support

## [0.2.0] - 2022-10-19

- Catch exceptions about irreversible migrations and show a warning
- Namespace all patches into gem module
- Fix typo in a module name with a patch
- Use guard clause

## [0.1.0] - 2022-10-16

- Initial release

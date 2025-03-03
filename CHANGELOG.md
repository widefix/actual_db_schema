## [0.8.3] - 2025-03-03

- View Schema with Migration Annotations in the UI
- Clean Up Broken Migrations
- Filter Migrations in the UI
- Customize Your Migrated Folder Location

## [0.8.2] - 2025-02-06

- Show migration name in the schema.rb diff that caused the change
- Easy way to run DDL migration methods in Rails console

## [0.8.1] - 2025-01-15

- Support for multiple database schemas, ensuring compatibility with multi-tenant applications using the apartment gem or similar solutions
- DSL for configuring the gem, simplifying setup and customization
- Rake task added to initialize the gem
- Improved the post-checkout git hook to run only when switching branches, reducing unnecessary executions during file checkouts
- Fixed the changelog link in the gemspec, ensuring Rubygems points to the correct file and the link works

## [0.8.0] - 2024-12-30
- Enhanced Console Visibility: Automatically rolled-back phantom migrations now provide clearer and more visible logs in the console
- Git Hooks for Branch Management: Introduced hooks that automatically rollback phantom migrations after checking out a branch. Additionally, the schema migration rake task can now be executed automatically upon branch checkout
- Temporary Folder Cleanup: Rolled-back phantom migrations are now automatically deleted from the temporary folder after rollback
- Acronym Support in Phantom Migration Names: Resolved an issue where phantom migrations with acronyms in their names, defined in other branches, couldn't be rolled back automatically. These are now handled seamlessly

## [0.7.9] - 2024-09-07
- Don't stop if a phantom migration rollback fails
- Improve failed rollback of phantom migrations report

## [0.7.8] - 2024-08-07
- Make UI working without assets pipeline

## [0.7.7] - 2024-07-22
- Unlock compatibility with Rails versions earlier than 6.0

## [0.7.6] - 2024-07-22
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

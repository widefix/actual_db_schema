# frozen_string_literal: true

module ActualDbSchema
  # Integrates the ConsoleMigrations module into the Rails console.
  class Railtie < ::Rails::Railtie
    console do
      require_relative "console_migrations"

      if ActualDbSchema.config[:console_migrations_enabled]
        TOPLEVEL_BINDING.receiver.extend(ActualDbSchema::ConsoleMigrations)
        puts "[ActualDbSchema] ConsoleMigrations enabled. You can now use migration methods directly at the console."
      end
    end
  end
end

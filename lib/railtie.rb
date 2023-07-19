# frozen_string_literal: true

require "rails"

module ActualDbSchema
  # Load the task into Rails app
  class Railtie < Rails::Railtie
    railtie_name :actual_db_schema

    rake_tasks do
      path = File.expand_path(__dir__)
      Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
    end
  end
end

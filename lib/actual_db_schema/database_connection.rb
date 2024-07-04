# frozen_string_literal: true

module ActualDbSchema
  class DatabaseConnection
    include Singleton

    def for_each_db_connection
      configs.each do |db_config|
        establish_connection(db_config)
        yield context
      end
    end

    private

    def establish_connection(db_config)
      config = db_config.respond_to?(:config) ? db_config.config : db_config
      ActiveRecord::Base.establish_connection(config)
    end

    def configs
      ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env)
    end

    def context
      ar_version = Gem::Version.new(ActiveRecord::VERSION::STRING)
      @context ||= if ar_version >= Gem::Version.new("7.2.0") ||
                      (ar_version >= Gem::Version.new("7.1.0") && ar_version.prerelease?)
                     ActiveRecord::Base.connection_pool.migration_context
                   else
                     ActiveRecord::Base.connection.migration_context
                   end
      @context.extend(ActualDbSchema::Patches::MigrationContext)
    end
  end
end

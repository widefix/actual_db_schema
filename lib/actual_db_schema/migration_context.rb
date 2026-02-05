# frozen_string_literal: true

module ActualDbSchema
  # The class manages connections to each database and provides the appropriate migration context for each connection.
  class MigrationContext
    include Singleton

    def each
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
      all_configs = if ActiveRecord::Base.configurations.is_a?(Hash)
                      # Rails < 6.0 has a Hash in configurations
                      [ActiveRecord::Base.configurations[ActiveRecord::Tasks::DatabaseTasks.env]]
                    else
                      ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env)
                    end

      filter_configs(all_configs)
    end

    def filter_configs(all_configs)
      # Handle Rails < 6.0 where configs is a Hash
      if all_configs.is_a?(Array) && all_configs.first.is_a?(Hash) && !all_configs.first.respond_to?(:name)
        # For Rails < 6.0, we have a single Hash with database names as keys
        filtered_hash = all_configs.first.reject do |db_name, _config|
          ActualDbSchema.config.excluded_databases.include?(db_name.to_sym)
        end
        return [filtered_hash]
      end

      # Handle Rails >= 6.0 where configs is an array of config objects
      all_configs.reject do |db_config|
        # Skip if database is in the excluded list
        # Rails 6.0 uses spec_name, Rails 6.1+ uses name
        db_name = if db_config.respond_to?(:name)
                    db_config.name.to_sym
                  elsif db_config.respond_to?(:spec_name)
                    db_config.spec_name.to_sym
                  else
                    :primary
                  end
        ActualDbSchema.config.excluded_databases.include?(db_name)
      end
    end

    def context
      ar_version = Gem::Version.new(ActiveRecord::VERSION::STRING)
      context = if ar_version >= Gem::Version.new("7.2.0") ||
                   (ar_version >= Gem::Version.new("7.1.0") && ar_version.prerelease?)
                  ActiveRecord::Base.connection_pool.migration_context
                else
                  ActiveRecord::Base.connection.migration_context
                end
      context.extend(ActualDbSchema::Patches::MigrationContext)
    end
  end
end

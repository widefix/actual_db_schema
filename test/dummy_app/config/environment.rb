ENV['PRIMARY_MIGRATIONS_PATH'] = Rails.root.join('db', 'migrate').to_s
ENV['SECONDARY_MIGRATIONS_PATH'] = Rails.root.join('db', 'migrate_secondary').to_s

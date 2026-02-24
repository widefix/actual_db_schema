# frozen_string_literal: true

module ActualDbSchema
  class RollbackStatsRepository
    TABLE_NAME = "actual_db_schema_rollback_events"

    class << self
      def record(payload)
        ensure_table!
        connection.execute(<<~SQL.squish)
          INSERT INTO #{quoted_table}
            (#{quoted_column("version")}, #{quoted_column("name")}, #{quoted_column("database")},
             #{quoted_column("schema")}, #{quoted_column("branch")}, #{quoted_column("manual_mode")},
             #{quoted_column("created_at")})
          VALUES
            (#{connection.quote(payload[:version].to_s)}, #{connection.quote(payload[:name].to_s)},
             #{connection.quote(payload[:database].to_s)}, #{connection.quote((payload[:schema] || "default").to_s)},
             #{connection.quote(payload[:branch].to_s)}, #{connection.quote(!!payload[:manual_mode])},
             #{connection.quote(Time.current)})
        SQL
      end

      def stats
        return empty_stats unless table_exists?

        {
          total: total_rollbacks,
          by_database: aggregate_by(:database),
          by_schema: aggregate_by(:schema),
          by_branch: aggregate_by(:branch)
        }
      end

      def total_rollbacks
        return 0 unless table_exists?

        connection.select_value(<<~SQL.squish).to_i
          SELECT COUNT(*) FROM #{quoted_table}
        SQL
      end

      def reset!
        return unless table_exists?

        connection.execute("DELETE FROM #{quoted_table}")
      end

      private

      def ensure_table!
        return if table_exists?

        connection.create_table(TABLE_NAME) do |t|
          t.string :version, null: false
          t.string :name
          t.string :database, null: false
          t.string :schema
          t.string :branch, null: false
          t.boolean :manual_mode, null: false, default: false
          t.datetime :created_at, null: false
        end
      end

      def table_exists?
        connection.table_exists?(TABLE_NAME)
      end

      def aggregate_by(column)
        return {} unless table_exists?

        rows = connection.select_all(<<~SQL.squish)
          SELECT #{quoted_column(column)}, COUNT(*) AS cnt
          FROM #{quoted_table}
          GROUP BY #{quoted_column(column)}
        SQL
        rows.each_with_object(Hash.new(0)) { |row, h| h[row[column.to_s].to_s] = row["cnt"].to_i }
      end

      def empty_stats
        {
          total: 0,
          by_database: {},
          by_schema: {},
          by_branch: {}
        }
      end

      def connection
        ActiveRecord::Base.connection
      end

      def quoted_table
        connection.quote_table_name(TABLE_NAME)
      end

      def quoted_column(name)
        connection.quote_column_name(name)
      end
    end
  end
end

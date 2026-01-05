# frozen_string_literal: true

module ActualDbSchema
  class Store
    include Singleton

    Item = Struct.new(:version, :timestamp, :branch)

    def write(filename)
      adapter.write(filename)
      reset_source_cache
    end

    def read
      adapter.read
    end

    def migration_files
      adapter.migration_files
    end

    def delete(filename)
      adapter.delete(filename)
      reset_source_cache
    end

    def stored_migration?(filename)
      adapter.stored_migration?(filename)
    end

    def source_for(version)
      version = version.to_s

      return :db if db_versions.key?(version)
      return :file if file_versions.key?(version)

      :unknown
    end

    def materialize_all
      adapter.materialize_all
    end

    def reset_adapter
      @adapter = nil
      reset_source_cache
    end

    private

    def adapter
      @adapter ||= begin
        storage = ActualDbSchema.config[:migrations_storage].to_s
        storage == "db" ? DbAdapter.new : FileAdapter.new
      end
    end

    def reset_source_cache
      @db_versions = nil
      @file_versions = nil
    end

    def db_versions
      @db_versions ||= begin
        connection = ActiveRecord::Base.connection
        return {} unless connection.table_exists?(DbAdapter::TABLE_NAME)

        table = connection.quote_table_name(DbAdapter::TABLE_NAME)
        connection.select_values("SELECT version FROM #{table}").each_with_object({}) do |version, acc|
          acc[version.to_s] = true
        end
      rescue StandardError
        {}
      end
    end

    def file_versions
      @file_versions ||= FileAdapter.new.read
    rescue StandardError
      {}
    end

    # Stores migrated files on the filesystem with metadata in CSV.
    class FileAdapter
      def write(filename)
        basename = File.basename(filename)
        FileUtils.mkdir_p(folder)
        FileUtils.copy(filename, folder.join(basename))
        record_metadata(filename)
      end

      def read
        return {} unless File.exist?(store_file)

        CSV.read(store_file).map { |line| Item.new(*line) }.index_by(&:version)
      end

      def migration_files
        Dir["#{folder}/**/[0-9]*_*.rb"]
      end

      def delete(filename)
        File.delete(filename) if File.exist?(filename)
      end

      def stored_migration?(filename)
        filename.to_s.start_with?(folder.to_s)
      end

      def materialize_all
        nil
      end

      private

      def record_metadata(filename)
        version = File.basename(filename).scan(/(\d+)_.*\.rb/).first.first
        CSV.open(store_file, "a") do |csv|
          csv << [
            version,
            Time.current.iso8601,
            Git.current_branch
          ]
        end
      end

      def folder
        ActualDbSchema.migrated_folder
      end

      def store_file
        folder.join("metadata.csv")
      end
    end

    class DbAdapter
      TABLE_NAME = "actual_db_schema_migrations"

      def write(filename)
        ensure_table!

        version = extract_version(filename)
        return unless version

        basename = File.basename(filename)
        content = File.read(filename)
        upsert_record(version, basename, content, Git.current_branch, Time.current)
        write_cache_file(basename, content)
      end

      def read
        return {} unless table_exists?

        rows = connection.exec_query(<<~SQL.squish)
          SELECT version, migrated_at, branch
          FROM #{quoted_table}
        SQL

        rows.map do |row|
          Item.new(row["version"].to_s, row["migrated_at"], row["branch"])
        end.index_by(&:version)
      end

      def migration_files
        materialize_all
        Dir["#{folder}/**/[0-9]*_*.rb"]
      end

      def delete(filename)
        version = extract_version(filename)
        return unless version

        if table_exists?
          connection.execute(<<~SQL.squish)
            DELETE FROM #{quoted_table}
            WHERE #{quoted_column("version")} = #{connection.quote(version)}
          SQL
        end
        File.delete(filename) if File.exist?(filename)
      end

      def stored_migration?(filename)
        filename.to_s.start_with?(folder.to_s)
      end

      def materialize_all
        return unless table_exists?

        FileUtils.mkdir_p(folder)
        rows = connection.exec_query(<<~SQL.squish)
          SELECT filename, content
          FROM #{quoted_table}
        SQL

        rows.each do |row|
          write_cache_file(row["filename"], row["content"])
        end
      end

      private

      def upsert_record(version, basename, content, branch, migrated_at)
        if record_exists?(version)
          connection.execute(<<~SQL)
            UPDATE #{quoted_table}
            SET #{quoted_column("filename")} = #{connection.quote(basename)},
                #{quoted_column("content")} = #{connection.quote(content)},
                #{quoted_column("branch")} = #{connection.quote(branch)},
                #{quoted_column("migrated_at")} = #{connection.quote(migrated_at)}
            WHERE #{quoted_column("version")} = #{connection.quote(version)}
          SQL
        else
          connection.execute(<<~SQL)
            INSERT INTO #{quoted_table}
              (#{quoted_column("version")}, #{quoted_column("filename")}, #{quoted_column("content")},
               #{quoted_column("branch")}, #{quoted_column("migrated_at")})
            VALUES
              (#{connection.quote(version)}, #{connection.quote(basename)}, #{connection.quote(content)},
               #{connection.quote(branch)}, #{connection.quote(migrated_at)})
          SQL
        end
      end

      def record_exists?(version)
        connection.select_value(<<~SQL.squish).present?
          SELECT 1
          FROM #{quoted_table}
          WHERE #{quoted_column("version")} = #{connection.quote(version)}
          LIMIT 1
        SQL
      end

      def ensure_table!
        return if table_exists?

        connection.create_table(TABLE_NAME) do |t|
          t.string :version, null: false
          t.string :filename, null: false
          t.text :content, null: false
          t.string :branch
          t.datetime :migrated_at, null: false
        end

        connection.add_index(TABLE_NAME, :version, unique: true) unless connection.index_exists?(TABLE_NAME, :version)
      end

      def table_exists?
        connection.table_exists?(TABLE_NAME)
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

      def folder
        ActualDbSchema.migrated_folder
      end

      def write_cache_file(filename, content)
        FileUtils.mkdir_p(folder)
        path = folder.join(File.basename(filename))
        return if File.exist?(path) && File.read(path) == content

        File.write(path, content)
      end

      def extract_version(filename)
        match = File.basename(filename).scan(/(\d+)_.*\.rb/).first
        match&.first
      end
    end
  end
end

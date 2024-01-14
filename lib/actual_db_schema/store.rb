# frozen_string_literal: true

module ActualDbSchema
  # Stores the migrated files into the tmp folder
  class Store
    include Singleton

    Item = Struct.new(:version, :timestamp, :branch)

    def write(filename)
      basename = File.basename(filename)
      FileUtils.copy(filename, folder.join(basename))
      record_metadata(filename)
    end

    def read
      return {} unless File.exist?(store_file)

      CSV.read(store_file).map { |line| Item.new(*line) }.index_by(&:version)
    end

    private

    def record_metadata(filename)
      version = File.basename(filename).scan(/(\d+)_.*\.rb/).first.first
      CSV.open(store_file, "ab") do |csv|
        csv << [
          version,
          Time.current.iso8601,
          `git rev-parse --abbrev-ref HEAD`.strip
        ]
      end
    end

    def current_branch
      `git rev-parse --abbrev-ref HEAD`.strip
    rescue Errno::ENOENT
      "unknown"
    end

    def folder
      ActualDbSchema.migrated_folder
    end

    def store_file
      folder.join("metadata.csv")
    end
  end
end

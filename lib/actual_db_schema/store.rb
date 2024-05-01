# frozen_string_literal: true

module ActualDbSchema
  # Stores the migrated files into the tmp folder
  class Store
    include Singleton

    Item = Struct.new(:version, :timestamp, :branch)

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
end

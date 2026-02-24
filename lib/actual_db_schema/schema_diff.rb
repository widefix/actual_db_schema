# frozen_string_literal: true

require "tempfile"

module ActualDbSchema
  # Generates a diff of schema changes between the current schema file and the
  # last committed version, annotated with the migrations responsible for each change.
  class SchemaDiff
    include OutputFormatter

    SIGN_COLORS = {
      "+" => :green,
      "-" => :red
    }.freeze

    CHANGE_PATTERNS = {
      /t\.(\w+)\s+["']([^"']+)["']/ => :column,
      /t\.index\s+.*name:\s*["']([^"']+)["']/ => :index,
      /create_table\s+["']([^"']+)["']/ => :table
    }.freeze

    SQL_CHANGE_PATTERNS = {
      /CREATE (?:UNIQUE\s+)?INDEX\s+["']?([^"'\s]+)["']?\s+ON\s+([\w.]+)/i => :index,
      /CREATE TABLE\s+(\S+)\s+\(/i => :table,
      /CREATE SEQUENCE\s+(\S+)/i => :table,
      /ALTER SEQUENCE\s+(\S+)\s+OWNED BY\s+([\w.]+)/i => :table,
      /ALTER TABLE\s+ONLY\s+(\S+)\s+/i => :table
    }.freeze

    def initialize(schema_path, migrations_path)
      @schema_path = schema_path
      @migrations_path = migrations_path
    end

    def render
      if old_schema_content.nil? || old_schema_content.strip.empty?
        puts colorize("Could not retrieve old schema from git.", :red)
        return
      end

      diff_output = generate_diff(old_schema_content, new_schema_content)
      process_diff_output(diff_output)
    end

    private

    def old_schema_content
      @old_schema_content ||= begin
        output = `git show HEAD:#{@schema_path} 2>&1`
        $CHILD_STATUS.success? ? output : nil
      end
    end

    def new_schema_content
      @new_schema_content ||= File.read(@schema_path)
    end

    def parsed_old_schema
      @parsed_old_schema ||= parser_class.parse_string(old_schema_content.to_s)
    end

    def parsed_new_schema
      @parsed_new_schema ||= parser_class.parse_string(new_schema_content.to_s)
    end

    def parser_class
      structure_sql? ? StructureSqlParser : SchemaParser
    end

    def structure_sql?
      File.extname(@schema_path) == ".sql"
    end

    def migration_changes
      @migration_changes ||= begin
        migration_dirs = [@migrations_path] + migrated_folders
        MigrationParser.parse_all_migrations(migration_dirs)
      end
    end

    def migrated_folders
      ActualDbSchema::Store.instance.materialize_all
      dirs = find_migrated_folders

      configured_migrated_folder = ActualDbSchema.migrated_folder
      relative_migrated_folder = configured_migrated_folder.to_s.sub(%r{\A#{Regexp.escape(Rails.root.to_s)}/?}, "")
      dirs << relative_migrated_folder unless dirs.include?(relative_migrated_folder)

      dirs.map { |dir| dir.sub(%r{\A\./}, "") }.uniq
    end

    def find_migrated_folders
      path_parts = Pathname.new(@migrations_path).each_filename.to_a
      db_index = path_parts.index("db")
      return [] unless db_index

      base_path = db_index.zero? ? "." : File.join(*path_parts[0...db_index])
      Dir[File.join(base_path, "tmp", "migrated*")].select do |path|
        File.directory?(path) && File.basename(path).match?(/^migrated(_[a-zA-Z0-9_-]+)?$/)
      end
    end

    def generate_diff(old_content, new_content)
      Tempfile.create("old_schema") do |old_file|
        Tempfile.create("new_schema") do |new_file|
          old_file.write(old_content)
          new_file.write(new_content)
          old_file.rewind
          new_file.rewind

          return `diff -u #{old_file.path} #{new_file.path}`
        end
      end
    end

    def process_diff_output(diff_str)
      lines = diff_str.lines
      current_table = nil
      result_lines  = []

      lines.each do |line|
        if (hunk_match = line.match(/^@@\s+-(\d+),(\d+)\s+\+(\d+),(\d+)\s+@@/))
          current_table = find_table_in_new_schema(hunk_match[3].to_i)
        elsif (ct = line.match(/create_table\s+["']([^"']+)["']/) ||
          line.match(/CREATE TABLE\s+"?([^"\s]+)"?/i) || line.match(/ALTER TABLE\s+ONLY\s+(\S+)/i))
          current_table = normalize_table_name(ct[1])
        end

        result_lines << (%w[+ -].include?(line[0]) ? handle_diff_line(line, current_table) : line)
      end

      result_lines.join
    end

    def handle_diff_line(line, current_table)
      sign = line[0]
      line_content = line[1..]
      color = SIGN_COLORS[sign]

      action, name = detect_action_and_name(line_content, sign, current_table)
      annotation = action ? find_migrations(action, current_table, name) : []
      annotated_line = annotation.any? ? annotate_line(line, annotation) : line

      colorize(annotated_line, color)
    end

    def detect_action_and_name(line_content, sign, current_table)
      patterns = structure_sql? ? SQL_CHANGE_PATTERNS : CHANGE_PATTERNS
      action_map = {
        column: ->(md) { [guess_action(sign, current_table, md[2]), md[2]] },
        index: ->(md) { [sign == "+" ? :add_index : :remove_index, md[1]] },
        table: ->(_) { [sign == "+" ? :create_table : :drop_table, nil] }
      }

      patterns.each do |regex, kind|
        next unless (md = line_content.match(regex))

        action_proc = action_map[kind]
        return action_proc.call(md) if action_proc
      end

      if structure_sql? && current_table && (md = line_content.match(/^\s*"?(\w+)"?\s+(.+?)(?:,|\s*$)/i))
        return [guess_action(sign, current_table, md[1]), md[1]]
      end

      [nil, nil]
    end

    def guess_action(sign, table, col_name)
      case sign
      when "+"
        old_table = parsed_old_schema[table] || {}
        old_table[col_name].nil? ? :add_column : :change_column
      when "-"
        new_table = parsed_new_schema[table] || {}
        new_table[col_name].nil? ? :remove_column : :change_column
      end
    end

    def find_table_in_new_schema(new_line_number)
      current_table = nil

      new_schema_content.lines[0...new_line_number].each do |line|
        if (match = line.match(/create_table\s+["']([^"']+)["']/) || line.match(/CREATE TABLE\s+"?([^"\s]+)"?/i))
          current_table = normalize_table_name(match[1])
        end
      end
      current_table
    end

    def find_migrations(action, table_name, col_or_index_name)
      matches = []

      migration_changes.each do |file_path, changes|
        changes.each do |chg|
          next unless (structure_sql? && index_action?(action)) || chg[:table].to_s == table_name.to_s

          matches << file_path if migration_matches?(chg, action, col_or_index_name)
        end
      end

      matches
    end

    def index_action?(action)
      %i[add_index remove_index rename_index].include?(action)
    end

    def migration_matches?(chg, action, col_or_index_name)
      return chg[:action] == action if col_or_index_name.nil?

      matchers = {
        rename_column: -> { rename_column_matches?(chg, action, col_or_index_name) },
        rename_index: -> { rename_index_matches?(chg, action, col_or_index_name) },
        add_index: -> { index_matches?(chg, action, col_or_index_name) },
        remove_index: -> { index_matches?(chg, action, col_or_index_name) }
      }

      matchers.fetch(chg[:action], -> { column_matches?(chg, action, col_or_index_name) }).call
    end

    def rename_column_matches?(chg, action, col)
      (action == :remove_column && chg[:old_column].to_s == col.to_s) ||
        (action == :add_column && chg[:new_column].to_s == col.to_s)
    end

    def rename_index_matches?(chg, action, name)
      (action == :remove_index && chg[:old_name] == name) ||
        (action == :add_index && chg[:new_name] == name)
    end

    def index_matches?(chg, action, col_or_index_name)
      return false unless chg[:action] == action

      extract_migration_index_name(chg, chg[:table]) == col_or_index_name.to_s
    end

    def column_matches?(chg, action, col_name)
      chg[:column] && chg[:column].to_s == col_name.to_s && chg[:action] == action
    end

    def extract_migration_index_name(chg, table_name)
      return chg[:options][:name].to_s if chg[:options].is_a?(Hash) && chg[:options][:name]

      return "" unless (columns = chg[:columns])

      cols = columns.is_a?(Array) ? columns : [columns]
      "index_#{table_name}_on_#{cols.join("_and_")}"
    end

    def annotate_line(line, migration_file_paths)
      "#{line.chomp}#{colorize(" // #{migration_file_paths.join(", ")} //", :gray)}\n"
    end

    def normalize_table_name(table_name)
      return table_name unless structure_sql? && table_name.include?(".")

      table_name.split(".").last
    end
  end
end

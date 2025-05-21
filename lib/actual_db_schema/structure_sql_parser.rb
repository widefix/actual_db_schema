# frozen_string_literal: true

module ActualDbSchema
  # Parses the content of a `structure.sql` file into a structured hash representation.
  module StructureSqlParser
    module_function

    def parse_string(sql_content)
      schema = {}
      table_regex = /CREATE TABLE\s+(?:"?([\w.]+)"?)\s*\((.*?)\);/m
      sql_content.scan(table_regex) do |table_name, columns_section|
        schema[normalize_table_name(table_name)] = parse_columns(columns_section)
      end
      schema
    end

    def parse_columns(columns_section)
      columns = {}
      columns_section.each_line do |line|
        line.strip!
        next if line.empty? || line =~ /^(CONSTRAINT|PRIMARY KEY|FOREIGN KEY)/i

        match = line.match(/\A"?(?<col>\w+)"?\s+(?<type>\w+)(?<size>\s*\([\d,]+\))?/i)
        next unless match

        col_name = match[:col]
        col_type = match[:type].strip.downcase.to_sym
        options = {}
        columns[col_name] = { type: col_type, options: options }
      end

      columns
    end

    def normalize_table_name(table_name)
      return table_name unless table_name.include?(".")

      table_name.split(".").last
    end
  end
end

# frozen_string_literal: true

module ActualDbSchema
  # Generates an HTML representation of the schema diff,
  # annotated with the migrations responsible for each change.
  class SchemaDiffHtml < SchemaDiff
    def render_html(table_filter)
      return unless old_schema_content && !old_schema_content.strip.empty?

      @full_diff_html ||= generate_diff_html
      filter = table_filter.to_s.strip.downcase

      filter.empty? ? @full_diff_html : extract_table_section(@full_diff_html, filter)
    end

    private

    def generate_diff_html
      diff_output = generate_full_diff(old_schema_content, new_schema_content)
      return "<pre>#{ERB::Util.html_escape(new_schema_content)}</pre>" if diff_output.strip.empty?

      process_diff_output_for_html(diff_output)
    end

    def generate_full_diff(old_content, new_content)
      Tempfile.create("old_schema") do |old_file|
        Tempfile.create("new_schema") do |new_file|
          old_file.write(old_content)
          new_file.write(new_content)
          old_file.rewind
          new_file.rewind

          `diff -u -U 9999999 #{old_file.path} #{new_file.path}`
        end
      end
    end

    def process_diff_output_for_html(diff_str)
      current_table = nil
      result_lines = []
      @tables = {}
      table_start = nil
      block_depth = 1

      diff_str.lines.each do |line|
        next if line.start_with?("---") || line.start_with?("+++") || line.match(/^@@/)

        current_table, table_start, block_depth =
          process_table(line, current_table, table_start, result_lines.size, block_depth)
        result_lines << (%w[+ -].include?(line[0]) ? handle_diff_line_html(line, current_table) : line)
      end

      result_lines.join
    end

    def process_table(line, current_table, table_start, table_end, block_depth)
      if (ct = line.match(/create_table\s+["']([^"']+)["']/))
        return [ct[1], table_end, block_depth]
      end

      return [current_table, table_start, block_depth] unless current_table

      block_depth += line.scan(/\bdo\b/).size unless line.match(/create_table\s+["']([^"']+)["']/)
      block_depth -= line.scan(/\bend\b/).size

      if block_depth.zero?
        @tables[current_table] = { start: table_start, end: table_end }
        current_table = nil
        block_depth = 1
      end

      [current_table, table_start, block_depth]
    end

    def handle_diff_line_html(line, current_table)
      sign = line[0]
      line_content = line[1..]
      color = SIGN_COLORS[sign]

      action, name = detect_action_and_name(line_content, sign, current_table)
      annotation = action ? find_migrations(action, current_table, name) : []
      annotation.any? ? annotate_line(line, annotation, color) : colorize_html(line, color)
    end

    def annotate_line(line, migration_file_paths, color)
      links_html = migration_file_paths.map { |path| link_to_migration(path) }.join(", ")
      "#{colorize_html(line.chomp, color)}#{colorize_html(" // #{links_html} //", :gray)}\n"
    end

    def colorize_html(text, color)
      safe = ERB::Util.html_escape(text)

      case color
      when :green
        %(<span style="color: green">#{safe}</span>)
      when :red
        %(<span style="color: red">#{safe}</span>)
      when :gray
        %(<span style="color: gray">#{text}</span>)
      end
    end

    def link_to_migration(migration_file_path)
      migration = migrations.detect { |m| m.filename == migration_file_path }
      return ERB::Util.html_escape(migration_file_path) unless migration

      url = "migrations/#{migration.version}?database=#{migration.database}"
      "<a href=\"#{url}\">#{ERB::Util.html_escape(migration_file_path)}</a>"
    end

    def migrations
      @migrations ||= ActualDbSchema::Migration.instance.all
    end

    def extract_table_section(full_diff_html, table_name)
      return unless @tables[table_name]

      range = @tables[table_name]
      full_diff_html.lines[range[:start]..range[:end]].join
    end
  end
end

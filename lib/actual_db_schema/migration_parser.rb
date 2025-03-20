# frozen_string_literal: true

require "ast"
require "prism"

module ActualDbSchema
  # Parses migration files in a Rails application into a structured hash representation.
  module MigrationParser
    extend self

    PARSER_MAPPING = {
      add_column: ->(args) { parse_add_column(args) },
      change_column: ->(args) { parse_change_column(args) },
      remove_column: ->(args) { parse_remove_column(args) },
      rename_column: ->(args) { parse_rename_column(args) },
      add_index: ->(args) { parse_add_index(args) },
      remove_index: ->(args) { parse_remove_index(args) },
      rename_index: ->(args) { parse_rename_index(args) },
      create_table: ->(args) { parse_create_table(args) },
      drop_table: ->(args) { parse_drop_table(args) }
    }.freeze

    def parse_all_migrations(dirs)
      changes_by_path = {}
      handled_files = Set.new

      dirs.each do |dir|
        Dir["#{dir}/*.rb"].sort.each do |file|
          base_name = File.basename(file)
          next if handled_files.include?(base_name)

          changes = parse_file(file).yield_self { |ast| find_migration_changes(ast) }
          changes_by_path[file] = changes unless changes.empty?
          handled_files.add(base_name)
        end
      end

      changes_by_path
    end

    private

    def parse_file(file_path)
      Prism::Translation::Parser.parse_file(file_path)
    end

    def find_migration_changes(node)
      return [] unless node.is_a?(Parser::AST::Node)

      changes = []
      if node.type == :block
        return process_block_node(node)
      elsif node.type == :send
        changes.concat(process_send_node(node))
      end

      node.children.each { |child| changes.concat(find_migration_changes(child)) if child.is_a?(Parser::AST::Node) }

      changes
    end

    def process_block_node(node)
      changes = []
      send_node = node.children.first
      return changes unless send_node.type == :send

      method_name = send_node.children[1]
      return changes unless method_name == :create_table

      change = parse_create_table_with_block(send_node, node)
      changes << change if change
      changes
    end

    def process_send_node(node)
      changes = []
      _receiver, method_name, *args = node.children
      if (parser = PARSER_MAPPING[method_name])
        change = parser.call(args)
        changes << change if change
      end

      changes
    end

    def parse_add_column(args)
      return unless args.size >= 3

      {
        action: :add_column,
        table: sym_value(args[0]),
        column: sym_value(args[1]),
        type: sym_value(args[2]),
        options: parse_hash(args[3])
      }
    end

    def parse_change_column(args)
      return unless args.size >= 3

      {
        action: :change_column,
        table: sym_value(args[0]),
        column: sym_value(args[1]),
        type: sym_value(args[2]),
        options: parse_hash(args[3])
      }
    end

    def parse_remove_column(args)
      return unless args.size >= 2

      {
        action: :remove_column,
        table: sym_value(args[0]),
        column: sym_value(args[1]),
        options: parse_hash(args[2])
      }
    end

    def parse_rename_column(args)
      return unless args.size >= 3

      {
        action: :rename_column,
        table: sym_value(args[0]),
        old_column: sym_value(args[1]),
        new_column: sym_value(args[2])
      }
    end

    def parse_add_index(args)
      return unless args.size >= 2

      {
        action: :add_index,
        table: sym_value(args[0]),
        columns: array_or_single_value(args[1]),
        options: parse_hash(args[2])
      }
    end

    def parse_remove_index(args)
      return unless args.size >= 1

      {
        action: :remove_index,
        table: sym_value(args[0]),
        options: parse_hash(args[1])
      }
    end

    def parse_rename_index(args)
      return unless args.size >= 3

      {
        action: :rename_index,
        table: sym_value(args[0]),
        old_name: node_value(args[1]),
        new_name: node_value(args[2])
      }
    end

    def parse_create_table(args)
      return unless args.size >= 1

      {
        action: :create_table,
        table: sym_value(args[0]),
        options: parse_hash(args[1])
      }
    end

    def parse_drop_table(args)
      return unless args.size >= 1

      {
        action: :drop_table,
        table: sym_value(args[0]),
        options: parse_hash(args[1])
      }
    end

    def parse_create_table_with_block(send_node, block_node)
      args = send_node.children[2..]
      columns = parse_create_table_columns(block_node.children[2])
      {
        action: :create_table,
        table: sym_value(args[0]),
        options: parse_hash(args[1]),
        columns: columns
      }
    end

    def parse_create_table_columns(body_node)
      return [] unless body_node

      nodes = body_node.type == :begin ? body_node.children : [body_node]
      nodes.map { |node| parse_column_node(node) }.compact
    end

    def parse_column_node(node)
      return unless node.is_a?(Parser::AST::Node) && node.type == :send

      method = node.children[1]
      return parse_timestamps if method == :timestamps

      {
        column: sym_value(node.children[2]),
        type: method,
        options: parse_hash(node.children[3])
      }
    end

    def parse_timestamps
      [
        { column: :created_at, type: :datetime, options: { null: false } },
        { column: :updated_at, type: :datetime, options: { null: false } }
      ]
    end

    def sym_value(node)
      return nil unless node && node.type == :sym

      node.children.first
    end

    def array_or_single_value(node)
      return [] unless node

      if node.type == :array
        node.children.map { |child| node_value(child) }
      else
        node_value(node)
      end
    end

    def parse_hash(node)
      return {} unless node && node.type == :hash

      node.children.each_with_object({}) do |pair_node, result|
        key_node, value_node = pair_node.children
        key = sym_value(key_node) || node_value(key_node)
        value = node_value(value_node)
        result[key] = value
      end
    end

    def node_value(node)
      return nil unless node

      case node.type
      when :str, :sym, :int then node.children.first
      when true then true
      when false then false
      when nil then nil
      else
        node.children.first
      end
    end
  end
end

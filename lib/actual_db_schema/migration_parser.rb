# frozen_string_literal: true

require "prism"

module ActualDbSchema
  # Parses migration files in a Rails application into a structured hash representation.
  module MigrationParser
    extend self

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
      parse_result = Prism.parse_file(file_path)
      raise SyntaxError, "Migration #{file_path} is syntax invalid" unless parse_result.success?

      parse_result.value
    end

    def find_migration_changes(node)
      visitor = MigrationVisitor.new
      visitor.visit(node)
      visitor.changes
    end

    # Internal class used to process the AST and collect migration information.
    class MigrationVisitor < Prism::Visitor
      MAPPING = {
        add_column: ->(visitor, args) { visitor.parse_add_column(args) },
        change_column: ->(visitor, args) { visitor.parse_change_column(args) },
        remove_column: ->(visitor, args) { visitor.parse_remove_column(args) },
        rename_column: ->(visitor, args) { visitor.parse_rename_column(args) },
        add_index: ->(visitor, args) { visitor.parse_add_index(args) },
        remove_index: ->(visitor, args) { visitor.parse_remove_index(args) },
        rename_index: ->(visitor, args) { visitor.parse_rename_index(args) },
        create_table: ->(visitor, args) { visitor.parse_create_table(args) },
        drop_table: ->(visitor, args) { visitor.parse_drop_table(args) }
      }.freeze

      attr_reader :changes

      def initialize
        super
        @changes = []
      end

      def visit_call_node(node)
        arguments = node.arguments&.arguments
        if node.block
          return unless node.name == :create_table

          change = parse_create_table_with_block(arguments, node.block)
          @changes << change if change
        elsif arguments && (parser = MAPPING[node.name])
          change = parser.call(self, arguments)
          @changes << change if change

          return
        end
        super
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

      def parse_create_table_with_block(args, block_node)
        columns = parse_create_table_columns(block_node.body)
        {
          action: :create_table,
          table: sym_value(args[0]),
          options: parse_hash(args[1]),
          columns: columns
        }
      end

      def parse_create_table_columns(statements_node)
        return [] unless statements_node

        statements_node.body.map { |node| parse_column_node(node) }.compact
      end

      def parse_column_node(node)
        return unless node.is_a?(Prism::CallNode)

        method = node.name
        return parse_timestamps if method == :timestamps

        arguments = node.arguments&.arguments
        return unless arguments

        {
          column: sym_value(arguments[0]),
          type: method,
          options: parse_hash(arguments[1])
        }
      end

      def parse_timestamps
        [
          { column: :created_at, type: :datetime, options: { null: false } },
          { column: :updated_at, type: :datetime, options: { null: false } }
        ]
      end

      def sym_value(node)
        return nil unless node.is_a?(Prism::SymbolNode)

        node.value.to_sym
      end

      def array_or_single_value(node)
        return [] unless node

        if node.is_a?(Prism::ArrayNode)
          node.elements.map { |child| node_value(child) }
        else
          node_value(node)
        end
      end

      def parse_hash(node)
        return {} unless node.is_a?(Prism::KeywordHashNode)

        node.elements.each_with_object({}) do |assoc_node, result|
          key_node = assoc_node.key
          value_node = assoc_node.value
          key = sym_value(key_node) || node_value(key_node)
          value = node_value(value_node)
          result[key] = value
        end
      end

      def node_value(node)
        return nil unless node

        case node
        when Prism::StringNode then node.content
        when Prism::SymbolNode then node.value.to_sym
        when Prism::IntegerNode then node.value
        when Prism::TrueNode then true
        when Prism::FalseNode then false
        when Prism::NilNode then nil
        else
          node
        end
      end
    end
  end
end

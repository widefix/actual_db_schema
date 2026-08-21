# frozen_string_literal: true

require "prism"

module ActualDbSchema
  # Parses the content of a `schema.rb` file into a structured hash representation.
  module SchemaParser
    module_function

    def parse_string(schema_content)
      parse_result = Prism.parse(schema_content)
      raise SyntaxError, "Schema is syntax invalid" unless parse_result.success?

      visitor = SchemaVisitor.new
      visitor.visit(parse_result.value)
      visitor.schema
    end

    # Internal class used to visit a create_table block
    class CreateTableVisitor < Prism::Visitor
      attr_reader :columns

      def initialize(block_arg)
        super()
        @block_arg = block_arg
        @columns = {}
      end

      def visit_call_node(node)
        return unless node.receiver.is_a?(Prism::LocalVariableReadNode) && node.receiver.name == @block_arg

        if node.name == :timestamps
          name = "timestamps"
          options = {}
        else
          name_arg, *, keyword_args = node.arguments&.arguments
          name = extract_column_name(name_arg)
          options = extract_column_options(keyword_args)
        end
        return unless name

        @columns[name] = { type: node.message.to_sym, options: options }
      end

      def extract_column_name(node)
        case node
        when Prism::StringNode
          node.content
        when Prism::SymbolNode
          node.value
        end
      end

      def extract_column_options(node)
        return {} unless node.is_a?(Prism::KeywordHashNode)

        options = {}
        node.elements.each do |assoc_node|
          next unless assoc_node.is_a?(Prism::AssocNode)
          next unless (key = extract_key(assoc_node.key))

          options[key] = extract_literal(assoc_node.value)
        end
        options
      end

      def extract_key(node)
        case node
        when Prism::SymbolNode then node.value.to_sym
        when Prism::StringNode then node.content.to_sym
        end
      end

      def extract_literal(node)
        case node
        when Prism::TrueNode then true
        when Prism::FalseNode then false
        when Prism::IntegerNode then node.value
        when Prism::SymbolNode then node.value.to_sym
        when Prism::StringNode then node.content
        end
      end
    end

    # Internal class used to process the AST and collect schema information.
    class SchemaVisitor < Prism::Visitor
      attr_reader :schema

      def initialize
        super
        @schema = {}
      end

      def visit_call_node(node)
        if node.name == :create_table
          return unless node.block

          table_name = extract_table_name(node)
          return unless table_name

          columns = extract_columns(node.block)
          @schema[table_name] = columns
          return
        end
        super
      end

      private

      def extract_table_name(call_node)
        first_arg = call_node.arguments&.arguments&.first
        case first_arg
        when Prism::StringNode
          first_arg.content
        when Prism::SymbolNode
          first_arg.value
        end
      end

      def extract_columns(block_node)
        return unless (block_arg = block_node.locals&.first)

        v = CreateTableVisitor.new(block_arg)
        v.visit(block_node)
        v.columns
      end
    end
  end
end

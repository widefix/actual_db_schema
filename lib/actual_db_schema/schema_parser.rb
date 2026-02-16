# frozen_string_literal: true

require "parser/ast/processor"
require "prism"

module ActualDbSchema
  # Parses the content of a `schema.rb` file into a structured hash representation.
  module SchemaParser
    module_function

    def parse_string(schema_content)
      ast = Prism::Translation::Parser.parse(schema_content)

      collector = SchemaCollector.new
      collector.process(ast)
      collector.schema
    end

    # Internal class used to process the AST and collect schema information.
    class SchemaCollector < Parser::AST::Processor
      attr_reader :schema

      def initialize
        super()
        @schema = {}
      end

      def on_block(node)
        send_node, _args_node, body = *node

        if create_table_call?(send_node)
          table_name = extract_table_name(send_node)
          columns    = extract_columns(body)
          @schema[table_name] = columns if table_name
        end

        super
      end

      def on_send(node)
        _receiver, method_name, *args = *node
        if method_name == :create_table && args.any?
          table_name = extract_table_name(node)
          @schema[table_name] ||= {}
        end

        super
      end

      private

      def create_table_call?(node)
        return false unless node.is_a?(Parser::AST::Node)

        _receiver, method_name, *_args = node.children
        method_name == :create_table
      end

      def extract_table_name(send_node)
        _receiver, _method_name, table_arg, *_rest = send_node.children
        return unless table_arg

        case table_arg.type
        when :str then table_arg.children.first
        when :sym then table_arg.children.first.to_s
        end
      end

      def extract_columns(body_node)
        return {} unless body_node

        children = body_node.type == :begin ? body_node.children : [body_node]

        columns = {}
        children.each do |expr|
          col = process_column_node(expr)
          columns[col[:name]] = { type: col[:type], options: col[:options] } if col && col[:name]
        end
        columns
      end

      def process_column_node(node)
        return unless node.is_a?(Parser::AST::Node)
        return unless node.type == :send

        receiver, method_name, column_node, *args = node.children

        return unless receiver && receiver.type == :lvar

        return { name: "timestamps", type: :timestamps, options: {} } if method_name == :timestamps

        col_name = extract_column_name(column_node)
        options  = extract_column_options(args)

        { name: col_name, type: method_name, options: options }
      end

      def extract_column_name(node)
        return nil unless node.is_a?(Parser::AST::Node)

        case node.type
        when :str then node.children.first
        when :sym then node.children.first.to_s
        end
      end

      def extract_column_options(args)
        opts = {}
        args.each do |arg|
          next unless arg && arg.type == :hash

          opts.merge!(parse_hash(arg))
        end
        opts
      end

      def parse_hash(node)
        hash = {}
        return hash unless node && node.type == :hash

        node.children.each do |pair|
          key_node, value_node = pair.children
          key = extract_key(key_node)
          value = extract_literal(value_node)
          hash[key] = value
        end
        hash
      end

      def extract_key(node)
        return unless node.is_a?(Parser::AST::Node)

        case node.type
        when :sym then node.children.first
        when :str then node.children.first.to_sym
        end
      end

      def extract_literal(node)
        return unless node.is_a?(Parser::AST::Node)

        case node.type
        when :int, :str, :sym then node.children.first
        when true then true
        when false then false
        end
      end
    end
  end
end

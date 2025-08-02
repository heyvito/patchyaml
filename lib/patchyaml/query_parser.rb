# frozen_string_literal: true

module PatchYAML
  class QueryParser
    def self.parse(query) = new(query).parse

    def initialize(query)
      @path = []
      @pos = 0
      @start = 0
      @query = query.each_char.to_a
      @current_path = nil
    end

    def peek = @query[@pos]
    def advance = @query[@pos].tap { @pos += 1 }
    def eof? = @pos >= @query.length
    def matches?(char) = peek == char
    def mark = @start = @pos
    def value = @query[@start...@pos].join

    def digit?(value = nil)
      value = peek if value.nil?
      !value.nil? && value >= "0" && value <= "9"
    end

    def non_separator?
      peek != "[" && peek != "."
    end

    def push_path
      if @current_path
        @path << @current_path
        @current_path = nil
      end

      advance if peek == "."
      mark
    end

    def parse
      until eof?
        next parse_index if digit?

        case peek
        when "["
          parse_expression_path
        when "."
          push_path
        else
          parse_simple_path
        end
      end

      @path
    end

    def parse_index
      mark
      advance while digit?
      @current_path = { kind: :index, value: value.to_i }
      push_path
    end

    def parse_expression_path
      raise ArgumentError, "Expected '[', found #{peek} at index #{@pos}" unless peek == "["

      advance # Consume [
      mark
      advance until peek == "]" || eof?

      raise ArgumentError, "Unterminated expression path at index #{@pos}" unless peek == "]"

      v = value
      advance # Consume ]

      unless v.include? "="
        raise ArgumentError, "Invalid expression path at index #{@start}: Expected expression to be in the format " \
                             "key=value"
      end

      key, value = v.split("=", 2).map(&:strip)

      value = case
      when digit?(value[0])
        value.to_i
      when ['"', "'"].include?(value[0])
        parse_quoted(value)
      when "true"
        true
      when "false"
        false
      else
        value
      end

      @current_path = { kind: :expression, key:, value: }
      push_path
    end

    def parse_simple_path
      mark
      advance until !non_separator? || eof?
      @current_path = { kind: :simple, value: value }
      push_path
    end

    def parse_quoted(value)
      quote = value[0]
      escaping = false
      v = []
      chars = value[1...].each_char.to_a

      until chars.empty?
        ch = chars.shift

        if ch == "\\"
          escaping = true
          next
        end

        if escaping
          escaping = false

          case ch
          when quote
            v << quote
          else
            v << "\\"
            v << ch
          end
          next
        end

        break if ch == quote

        v << ch
      end

      unless chars.empty?
        raise ArgumentError, "Invalid expression #{value}: Stray #{chars.shift} after closing #{quote}"
      end

      v.join
    end
  end
end

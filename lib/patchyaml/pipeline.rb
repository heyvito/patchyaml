# frozen_string_literal: true

module PatchYAML
  class Editor
    def run_pipeline
      run_pipeline_once until @pipeline.empty?
      @data
    end

    private

    def run_pipeline_once
      op, *opts = @pipeline.shift
      case op
      when :delete
        node_delete(opts[0])
      when :rename
        node_rename(opts[0], opts[1])
      when :map_add
        node_map_add(opts[0], opts[1], opts[2])
      when :update
        node_update(opts[0], opts[1])
      when :seq_add
        node_seq_add(opts[0], opts[1], opts[2])
      else
        raise Error, "patchyaml: Unknown pipeline operation #{op}"
      end
      reload(@data)
    end

    def start_offset(node)
      @line_sizes[..node.start_line].sum + (node.start_column.positive? ? node.start_column : 0)
    end

    def end_offset(node)
      @line_sizes[..node.end_line].sum + (node.end_column.positive? ? node.end_column : 0)
    end

    def node_delete(path)
      value, parent = find(@stream, path)
      case parent
      when Psych::Nodes::Sequence
        start_at = start_offset(value)
        end_at = end_offset(value)
        if parent.style == Psych::Nodes::Sequence::FLOW
          # For flow-based sequences, like [1, 2, 3, 4], ensure we remove
          # any leading spaces and trailing commas, as they are not part
          # of the value itself. However, if the character before the space is
          # a "[", keep the space.
          start_at -= 1 if start_at >= 2 && @data[start_at - 1] == " " && @data[start_at - 2] != "["
          end_at += 1 if @data[end_at] == ","
        else
          # For block-based sequences, we can remove the whole line
          start_at = @line_sizes[..value.start_line].sum
          end_at = @line_sizes[..value.end_line].sum
        end
        @data = @data[...start_at].concat(@data[end_at...])
      when Psych::Nodes::Mapping
        value_index = parent.children.index(value)
        key_index = value_index - 1
        key = parent.children[key_index]
        value = parent.children[value_index]
        start_at = start_offset(key)
        end_at = end_offset(value)

        if parent.style == Psych::Nodes::Mapping::FLOW
          # For flow-based maps, like { a: 1, b: 2 }, ensure we remove
          # any leading spaces and trailing commas, as they are not part
          # of the k/v
          start_at -= 1 if !start_at.zero? && @data[start_at - 1] == " "
          end_at += 1 if @data[end_at] == ","
        else
          start_at = @line_sizes[..key.start_line].sum
          end_at = if value.end_line == key.start_line
            @line_sizes[..(value.end_line + 1)]
          else
            @line_sizes[..value.end_line]
          end.sum
        end

        @data = @data[...start_at].concat(@data[end_at...] || "")
      else
        raise Error, "patchyaml: BUG: cannot delete object from #{parent.class}"
      end
    end

    def dump_yaml(value, indent: 0)
      dump = Psych.dump(value, stringify_names: true).gsub(/---\s?\n?\s*/, "")
      return dump if indent.zero?

      arr = dump.split("\n")
      ([arr[0]] + arr[1..].map { "#{" " * indent}#{it}" }).join("\n")
    end

    def node_update(path, new_value)
      value, parent = find(@stream, path)
      case parent
      when Psych::Nodes::Mapping
        update_mapping(value, parent, new_value)
      when Psych::Nodes::Sequence
        update_sequence(value, parent, new_value)
      else
        raise TypeError, "Cannot update value of type #{parent.class}, expected Mapping or Sequence"
      end
    end

    # TODO: update_* does not take into consideration adding a complex, multiline
    # value into an inline parent. This will certainly break things.
    def update_mapping(value, parent, new_value)
      key_index = parent.children.index(value) - 1
      key = parent.children[key_index]
      start_at = start_offset(value)
      end_at = end_offset(value)
      end_at -= 1 if @data[end_at - 1] == "\n"
      yaml_value = dump_yaml(new_value, indent: key.start_column + 2)
      indent = case
      when new_value.is_a?(Hash)
        start_at -= 1 while @data[start_at - 1] == " "
        "\n#{" " * (key.start_column + 2)}"
      when (new_value.is_a?(Array) && parent.style != Psych::Nodes::Mapping::FLOW)
        start_at -= 1 while @data[start_at - 1] == " "
        "#{" " * (key.start_column + 2)}"
      else
        ""
      end
      @data = @data[...start_at]
        .concat(indent)
        .concat(yaml_value)
        .concat(@data[end_at...])
    end

    def update_sequence(value, parent, new_value)
      start_at = start_offset(value)
      end_at = end_offset(value)
      end_at -= 1 if @data[end_at - 1] == "\n"

      if parent.style == Psych::Nodes::Sequence::FLOW
        if new_value.is_a?(Array) || new_value.is_a?(Hash)
          raise Error, "Cannot update node as its parent is in flow-style."
        end

        yaml_value = dump_yaml(new_value)
        yaml_value = yaml_value.strip
      else
        yaml_value = dump_yaml(new_value)
        yaml_value = "#{yaml_value}\n" unless yaml_value.end_with?("\n")
        yaml_value = "#{yaml_value}#{" " * value.end_column}"
      end
      @data = @data[...start_at]
        .concat(yaml_value)
        .concat(@data[end_at...])
    end

    def node_rename(path, new_name)
      value, parent = find(@stream, path)
      raise TypeError, "Cannot rename sequence" if parent.is_a? Psych::Nodes::Sequence

      key_index = parent.children.index(value) - 1
      key = parent.children[key_index]
      start_at = start_offset(key)
      end_at = end_offset(key)
      @data = @data[...start_at].concat(new_name).concat(@data[end_at...])
    end

    def reindent(value, level:)
      value
        .split("\n")
        .map { "#{" " * level}#{it}" }
        .join("\n")
    end

    def node_map_add(path, key, value)
      node, = find(@stream, path)
      unless node.is_a?(Psych::Nodes::Mapping)
        raise TypeError, "Cannot add key to non-mapping node of type #{node.class}"
      end

      encoded_value = dump_yaml(value)

      # Adding an inline (flow) and block map differs a little. We are currently
      # avoiding adding complex values to inline items, but adding simple
      # values. For an empty node, we can add in our own style (space after
      # and before curlies), otherwise, just add a comma, a space, the
      # key/value, and a trailing space (if the node has a leading space after
      # the curly)
      @data = if node.style == Psych::Nodes::Mapping::FLOW
        node_map_add_inline(node, key, value, encoded_value)
      else
        node_map_add_block(node, key, value, encoded_value)
      end
    end

    def node_map_add_block(node, key, value, encoded_value)
      indent_level, start_at = if node.children.length.positive?
        [node.children.first.start_column, end_offset(node.children.last)]
      else
        [parent.first.start_column, end_offset(parent)]
      end

      if value.is_a?(Array) || value.is_a?(Hash)
        encoded_value = reindent(encoded_value, level: indent_level + 2)
        return @data[..start_at]
            .concat("#{" " * indent_level}#{key}:\n#{encoded_value}")
            .concat(@data[start_at...])
      end

      @data[..start_at]
        .concat("#{" " * indent_level}#{key}: #{encoded_value.strip}")
        .concat(@data[start_at...])
    end

    def node_map_add_inline(node, key, value, encoded_value)
      raise Error, "Cannot add complex values to inline mapping" if value.is_a?(Hash) || value.is_a?(Array)

      if node.children.length.positive?
        end_off = end_offset(node.children.last)
        start_at = start_offset(node.children.last)
        start_at -= 1 if @data[start_at] == " "
        return @data[..start_at]
            .concat(", #{key}: #{encoded_value.strip}")
            .concat(@data[end_off...])
      end

      end_off = end_offset(node)
      start_at = start_offset(node)
      start_at -= 1 if @data[start_at] == " "
      @data[..start_at]
        .concat(" #{key}: #{encoded_value.strip} ")
        .concat(@data[(end_off - 1)...])
    end

    def node_seq_add(path, value, index)
      node, = find(@stream, path)
      unless node.is_a?(Psych::Nodes::Sequence)
        raise TypeError, "Cannot add item to non-sequence node of type #{node.class}"
      end

      encoded_value = dump_yaml(value)

      # Adding an inline (flow) and block map differs a little. We are currently
      # avoiding adding complex values to inline items, but adding simple
      # values. For an empty node, we can add in our own style (space after
      # and before curlies), otherwise, just add a comma, a space, the
      # key/value, and a trailing space (if the node has a leading space after
      # the curly)
      @data = if node.style == Psych::Nodes::Sequence::FLOW
        node_seq_add_inline(node, value, encoded_value, index)
      else
        node_seq_add_block(node, value, encoded_value, index)
      end
    end

    def node_seq_add_inline(node, value, encoded_value, index)
      raise Error, "Cannot add complex values to inline mapping" if value.is_a?(Hash) || value.is_a?(Array)

      if node.children.length.positive?
        start_at, prefix, suffix = if index.nil?
          [end_offset(node.children.last), ", ", ""]
        else
          item = node.children[index] || node.children.last
          p, s = item == node.children.last ? [", ", ""] : ["", ", "]
          [start_offset(item), p, s]
        end
        start_at -= 1 if @data[start_at] == " "
        return @data[...start_at]
            .concat(prefix)
            .concat(encoded_value.strip)
            .concat(suffix)
            .concat(@data[start_at...])
      end

      end_off = end_offset(node)
      start_at = start_offset(node)
      start_at -= 1 if @data[start_at] == " "
      @data[..start_at]
        .concat(" #{encoded_value.strip} ")
        .concat(@data[(end_off - 1)...])
    end

    def node_seq_add_block(node, value, encoded_value, index)
      indent_level, start_at = if node.children.length.positive?
        start = node.children.first.start_column
        start_off = start_offset(node.children.first)
        until @data[start_off] == "-"
          start_off -= 1
          start -= 1
        end
        ref = index.nil? ? end_offset(node.children.last) : start_offset(node.children[index])
        [start, ref]
      else
        [parent.first.start_column, end_offset(parent)]
      end
      start_at -= 1 until @data[start_at - 1] == "\n" || @data[start_at].nil?

      if value.is_a?(Array) || value.is_a?(Hash)
        encoded_value = encoded_value.split("\n")
        encoded_value = [encoded_value.first] + encoded_value[1...].map { (" " * (indent_level + 2)).concat(it) }
        encoded_value = encoded_value.join("\n")
        return @data[...start_at]
            .concat("#{" " * indent_level}- #{encoded_value}\n")
            .concat(@data[start_at...])
      end

      @data[...start_at]
        .concat("#{" " * indent_level}- #{encoded_value.strip}")
        .concat(@data[start_at...])
    end
  end
end

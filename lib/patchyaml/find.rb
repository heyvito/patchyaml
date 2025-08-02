# frozen_string_literal: true

module PatchYAML
  class Editor
    def find(from, path)
      path = QueryParser.parse(path)
      # Pass through Psych::Nodes::Stream -> Psych::Nodes::Document
      node = [from, nil]
      path.each do |part|
        node = find_node(node, part)
        return [] if node.empty?
      end
      node
    end

    def find_node(from, part)
      case part[:kind]
      when :simple
        case from.first
        when Psych::Nodes::Stream, Psych::Nodes::Document
          find_node([from.first.children.first, from], part)
        when Psych::Nodes::Mapping
          find_mapping_key(from.first, part[:value])
        when Psych::Nodes::Sequence
          [from.first.children.find { it.respond_to?(:value) && it.value == part[:value] }, from.first]
        when Psych::Nodes::Alias
          node = @anchors[from.first.anchor]
          raise "patchyaml: Unknown anchor #{from.anchor} defined by #{from.first}" unless node

          [find_node(node, part), node]
        else
          raise "patchyaml: Unexpected node #{from.first.class} in #find_node"
        end
      when :index
        case from.first
        when Psych::Nodes::Stream, Psych::Nodes::Document
          [find_node(from.first.children.first, part[:value]), from.first]
        when Psych::Nodes::Sequence
          [from.first.children[part[:value]], from.first]
        end
      when :expression
        case from.first
        when Psych::Nodes::Stream, Psych::Nodes::Document
          [find_node(from.first.children.first, part), from.first]
        when Psych::Nodes::Sequence
          v = from
            .first
            .children
            .find { it.is_a?(Psych::Nodes::Mapping) && find_mapping_key(it, part[:key]).value == part[:value] }
          [v, from]
        end
      end
    end

    def find_mapping_key(from, named)
      # A mapping is basically an even-numbered array containing keys followed by their values.
      # Keys are expressed as an scalar value.
      i = 0
      until i >= from.children.size - 1
        if from.children[i].value == named
          result = from.children[i + 1]
          return [result, from] unless result.is_a?(Psych::Nodes::Alias)

          item = @anchors[result.anchor]
          raise "patchyaml: Unknown anchor #{result.anchor} defined by #{result}" unless item

          return [item, from]
        end

        i += 2
      end
      [nil, from]
    end
  end
end

# frozen_string_literal: true

module PatchYAML
  class Editor
    def process_anchor(from)
      @anchors[from.anchor] = from if !from.is_a?(Psych::Nodes::Alias) && from.respond_to?(:anchor) && !from.anchor.nil?

      case from
      when Psych::Nodes::Stream, Psych::Nodes::Document
        process_anchor(from.children.first)
      when Psych::Nodes::Mapping
        process_anchor_map(from)
      when Psych::Nodes::Sequence
        from.children.each { process_anchor(it) }
      when Psych::Nodes::Scalar, Psych::Nodes::Alias
        # noop
      else
        raise "patchyaml: Unexpected node #{from.class} in #process_anchor"
      end
    end

    def process_anchor_map(from)
      from.children.each.with_index do |item, idx|
        process_anchor(item) if idx.odd?
      end
    end
  end
end

# frozen_string_literal: true

require "yaml"

require_relative "patchyaml/version"
require_relative "patchyaml/editor"
require_relative "patchyaml/anchors"
require_relative "patchyaml/find"
require_relative "patchyaml/query_parser"
require_relative "patchyaml/pipeline"

module PatchYAML
  class Error < StandardError; end

  def self.load(data)
    Editor.new(data)
  end

  def self.load_file(path)
    Editor.new(File.read(path))
  end
end

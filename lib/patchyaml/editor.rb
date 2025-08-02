# frozen_string_literal: true

module PatchYAML
  class Editor
    def initialize(data)
      @anchors = {}
      @pipeline = []

      reload(data)
    end

    # Deletes a given path from the yaml
    #
    # path - The path to the key to be deleted
    #
    # Returns the same Editor instance
    def delete(path) = tap { @pipeline << [:delete, path] }

    # Updates an existing path in the yaml to have the provided value
    #
    # path - The path to the key to be updated
    # value - The value to be set in the key
    #
    # Returns the same Editor instance
    def update(path, value) = tap { @pipeline << [:update, path, value] }

    # Renames a given path
    #
    # path - The path to the key to be renamed
    # to:  - The new name of the key
    #
    # Returns the same Editor instance
    def map_rename(path, to:)
      tap { @pipeline << [:rename, path, to] }
    end

    # Adds a new key to the yaml
    #
    # path  - The path to the mapping that will receive the new key
    # key   - The new key name
    # value - The new key value
    #
    # Returns the same Editor instance
    def map_add(path, key, value)
      tap { @pipeline << [:map_add, path, key, value] }
    end

    # Adds a new value to a sequence
    #
    # path   - The path to the sequence that will receive the new item
    # value  - The value to be added to the sequence
    # index: - The index to insert the value into. Defaults to nil, and
    #          appends to the end of the sequence.
    #
    # Returns the same Editor instance
    def seq_add(path, value, index: nil)
      tap { @pipeline << [:seq_add, path, value, index] }
    end

    # Returns the processed YAML after edits have been applied.
    def yaml = run_pipeline

    private

    def reload(data)
      @data = data
      @line_sizes = [0] + data.split("\n").map { it.length + 1 }
      begin
        @stream = Psych.parse_stream(data)
      rescue Psych::SyntaxError
        puts "Parsing failed. Input was:\n#{@data}"
        raise
      end
      process_anchor(@stream)
    end
  end
end

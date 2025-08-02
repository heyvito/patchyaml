# frozen_string_literal: true

RSpec.describe PatchYAML do
  let(:value) do
    <<~YAML
      mapping:
        a:
          sequence:
            - name: a
            - name: b
            - name: c
            - name: d
              otherValue: hello
        b: foo
        c: true
        d: [1, 2, 3, 4, foo, bar, hello]
      d: 1
      empty:
      e: { a: 1, b: 2, c: 3 }
      f: [1, 2, 3, 4, hello]
      g: {}
      h: []
    YAML
  end
  let(:editor) { PatchYAML.load(value) }

  context "delete" do
    it "deletes a value" do
      editor.delete("d")
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "deletes a value at EOF" do
      editor.delete("e")
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "deletes a whole mapping" do
      editor.delete("mapping")
      expect(editor.yaml).to eq(<<~YAML)
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "deletes from a sequence" do
      editor.delete("mapping.a.sequence.2")
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "deletes from a sequence with multiple lines" do
      editor.delete("mapping.a.sequence.3")
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "deletes from an inline sequence" do
      editor.delete("mapping.d.4")
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "deletes from an inline mapping" do
      editor.delete("e.b")
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end
  end

  context "update" do
    context "mapping" do
      it "updates value at root" do
        editor.update("d", "henlo")
        expect(editor.yaml).to eq(<<~YAML)
          mapping:
            a:
              sequence:
                - name: a
                - name: b
                - name: c
                - name: d
                  otherValue: hello
            b: foo
            c: true
            d: [1, 2, 3, 4, foo, bar, hello]
          d: henlo
          empty:
          e: { a: 1, b: 2, c: 3 }
          f: [1, 2, 3, 4, hello]
          g: {}
          h: []
        YAML
      end

      it "updates value at level one" do
        editor.update("mapping.b", "henlo")
        expect(editor.yaml).to eq(<<~YAML)
          mapping:
            a:
              sequence:
                - name: a
                - name: b
                - name: c
                - name: d
                  otherValue: hello
            b: henlo
            c: true
            d: [1, 2, 3, 4, foo, bar, hello]
          d: 1
          empty:
          e: { a: 1, b: 2, c: 3 }
          f: [1, 2, 3, 4, hello]
          g: {}
          h: []
        YAML
      end

      it "updates value in deeper levels" do
        editor.update("mapping.a.sequence.3.otherValue", "henlo")
        expect(editor.yaml).to eq(<<~YAML)
          mapping:
            a:
              sequence:
                - name: a
                - name: b
                - name: c
                - name: d
                  otherValue: henlo
            b: foo
            c: true
            d: [1, 2, 3, 4, foo, bar, hello]
          d: 1
          empty:
          e: { a: 1, b: 2, c: 3 }
          f: [1, 2, 3, 4, hello]
          g: {}
          h: []
        YAML
      end

      it "updates values in inline mappings" do
        editor.update("e.b", "henlo")
        expect(editor.yaml).to eq(<<~YAML)
          mapping:
            a:
              sequence:
                - name: a
                - name: b
                - name: c
                - name: d
                  otherValue: hello
            b: foo
            c: true
            d: [1, 2, 3, 4, foo, bar, hello]
          d: 1
          empty:
          e: { a: 1, b: henlo, c: 3 }
          f: [1, 2, 3, 4, hello]
          g: {}
          h: []
        YAML
      end

      it "updates values to multiline values" do
        editor.update("mapping.a.sequence.3.otherValue", { name: "henlo", email: "henlo@henlo.io" })
        expect(editor.yaml).to eq(<<~YAML)
          mapping:
            a:
              sequence:
                - name: a
                - name: b
                - name: c
                - name: d
                  otherValue:
                    name: henlo
                    email: henlo@henlo.io
            b: foo
            c: true
            d: [1, 2, 3, 4, foo, bar, hello]
          d: 1
          empty:
          e: { a: 1, b: 2, c: 3 }
          f: [1, 2, 3, 4, hello]
          g: {}
          h: []
        YAML
      end
    end

    context "sequence" do
      it "updates a value on the root level" do
        editor.update("f.1", 0)
        expect(editor.yaml).to eq(<<~YAML)
          mapping:
            a:
              sequence:
                - name: a
                - name: b
                - name: c
                - name: d
                  otherValue: hello
            b: foo
            c: true
            d: [1, 2, 3, 4, foo, bar, hello]
          d: 1
          empty:
          e: { a: 1, b: 2, c: 3 }
          f: [1, 0, 3, 4, hello]
          g: {}
          h: []
        YAML
      end

      it "updates a value on deeper level" do
        editor.update("mapping.a.sequence.0", { henlo: true })
        expect(editor.yaml).to eq(<<~YAML)
          mapping:
            a:
              sequence:
                - henlo: true
                - name: b
                - name: c
                - name: d
                  otherValue: hello
            b: foo
            c: true
            d: [1, 2, 3, 4, foo, bar, hello]
          d: 1
          empty:
          e: { a: 1, b: 2, c: 3 }
          f: [1, 2, 3, 4, hello]
          g: {}
          h: []
        YAML
      end

      it "updates a value on inline sequence" do
        editor.update("f.1", false)
        expect(editor.yaml).to eq(<<~YAML)
          mapping:
            a:
              sequence:
                - name: a
                - name: b
                - name: c
                - name: d
                  otherValue: hello
            b: foo
            c: true
            d: [1, 2, 3, 4, foo, bar, hello]
          d: 1
          empty:
          e: { a: 1, b: 2, c: 3 }
          f: [1, false, 3, 4, hello]
          g: {}
          h: []
        YAML
      end

      it "updates a complex value on inline sequence" do
        editor.update("f.1", { foo: true })
        expect do
          editor.yaml
        end.to raise_error(PatchYAML::Error)
      end
    end
  end

  context "rename" do
    it "renames a root node" do
      editor.map_rename("mapping", to: "mappings")
      expect(editor.yaml).to eq(<<~YAML)
        mappings:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "renames a deep node" do
      editor.map_rename("mapping.a.sequence.0.name", to: "email")
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - email: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end
  end

  context "map_add" do
    it "adds an item to a block map" do
      editor.map_add("mapping", "test", true)
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
          test: true
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "adds a mapping item to a block map" do
      editor.map_add("mapping", "test", { name: "test", test: true })
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
          test:
            name: test
            test: true
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "adds a sequence item to a block map" do
      editor.map_add("mapping", "test", %w[foo bar baz])
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
          test:
            - foo
            - bar
            - baz
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "adds a simple item to an inline mapping" do
      editor.map_add("e", "d", 4)
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3, d: 4 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "adds a simple item to an empty inline mapping" do
      editor.map_add("g", "d", 4)
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: { d: 4 }
        h: []
      YAML
    end

    it "refuses to add a complex item to an inline mapping" do
      editor.map_add("e", "d", { name: "henlo" })
      expect { editor.yaml }.to raise_error(PatchYAML::Error)
    end
  end

  context "seq_add" do
    it "adds a simple item to a sequence" do
      editor.seq_add("mapping.a.sequence", { name: "e" })
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
              - name: e
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "adds a simple item to a sequence with index" do
      editor.seq_add("mapping.a.sequence", { name: "e" }, index: 0)
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: e
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "adds a multiline item to a sequence" do
      editor.seq_add("mapping.a.sequence", { name: "e", email: "e@e.e" })
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
              - name: e
                email: e@e.e
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "adds a multiline item to a sequence with index" do
      editor.seq_add("mapping.a.sequence", { name: "e", email: "e@e.e" }, index: 0)
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: e
                email: e@e.e
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "adds a simple item to an inline sequence" do
      editor.seq_add("mapping.d", "henlo")
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello, henlo]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "adds a simple item to an inline sequence with index" do
      editor.seq_add("mapping.d", "henlo", index: 0)
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [henlo, 1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: []
      YAML
    end

    it "refuses to a add a complex item to an inline sequence" do
      editor.seq_add("f", { name: "henlo" })
      expect { editor.yaml }.to raise_error(PatchYAML::Error)
    end

    it "adds an item to an empty inline sequence" do
      editor.seq_add("h", 1)
      expect(editor.yaml).to eq(<<~YAML)
        mapping:
          a:
            sequence:
              - name: a
              - name: b
              - name: c
              - name: d
                otherValue: hello
          b: foo
          c: true
          d: [1, 2, 3, 4, foo, bar, hello]
        d: 1
        empty:
        e: { a: 1, b: 2, c: 3 }
        f: [1, 2, 3, 4, hello]
        g: {}
        h: [ 1 ]
      YAML
    end
  end
end

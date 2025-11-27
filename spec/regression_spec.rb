# frozen_string_literal: true

RSpec.describe PatchYAML do
  it "correctly updates without weirdnesses" do
    editor = PatchYAML.load(<<~YAML)
    some-app:
      staticDeploy:
        enabled: true
        buckets:
          some-staging:
            version: 0.11.22
            invalidations:
              SOMESTRANGEID:
                - "/strict/path/example/sample/file.html"
                - "/strict/path/example2/*"
    YAML
    bump_path = "some-app.staticDeploy.buckets.some-staging.invalidations.SOMESTRANGEID"
    editor.update(bump_path, ["1", "2"])
    expect(editor.yaml).to eq(<<~YAML)
      some-app:
        staticDeploy:
          enabled: true
          buckets:
            some-staging:
              version: 0.11.22
              invalidations:
                SOMESTRANGEID:
                  - '1'
                  - '2'
    YAML

  end

  it "correctly updates keys after lists" do
    file = <<~YAML
    some-app:
      staticDeploy:
        enabled: true
        buckets:
          some-staging:
            version: 0.11.22
            invalidations:
              SOMESTRANGEID:
                - "a/*"
                - "b/*"
                - "c/*"
                - "d/*"
                - "e/*"
                - "f/*"
                - "g/*"
                - "h/*"
                - "assets/*"
                - "foo/*"
                - "/bar"
            sha: foobar
    YAML

    y_path1 = "some-app.staticDeploy.buckets.some-staging.invalidations.SOMESTRANGEID"
    u_val1 = [
                "a/*",
                "b/*",
                "c/*",
                "d/*",
                "e/*",
                "f/*",
                "g/*",
                "h/*",
                "assets/*",
                "foo/*",
                "/bar",
    ]

    y_path2 = "some-app.staticDeploy.buckets.some-staging.sha"

    updates = {
      y_path1 => u_val1,
      y_path2 => "barfoo"
    }

    updates.each do |yaml_path, new_value|
      editor = PatchYAML.load(file)
      editor.update(yaml_path, new_value)
      file = editor.yaml
    end
  end

  it "does not overflows on end_offset" do
    value = <<~YAML.strip
    some-app:
      staticDeploy:
        enabled: true
        buckets:
          some-staging:
            version: 0.11.22
            invalidations:
              SOMESTRANGEID:
                - "/strict/path/example/sample/file.html"
                - "/strict/path/example2/*"
    YAML
    bump_path = "some-app.staticDeploy.buckets.some-staging.invalidations.SOMESTRANGEID"
    editor = PatchYAML.load(value)
    editor.update(bump_path, ["3", "4"])
    result = ""
    expect { result = editor.yaml }.to_not raise_error
    expect(result).to eq(<<~YAML)
      some-app:
        staticDeploy:
          enabled: true
          buckets:
            some-staging:
              version: 0.11.22
              invalidations:
                SOMESTRANGEID:
                  - '3'
                  - '4'
    YAML
  end

  it "correctly replaces empty flow sequences" do
    value = <<~YAML
    a:
      b: []
    YAML

    editor = PatchYAML.load(value)
    editor.update("a.b", ["3", "4"])
    expect(editor.yaml).to eq(<<~YAML)
      a:
        b:
          - '3'
          - '4'
    YAML
  end
end

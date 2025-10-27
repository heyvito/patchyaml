# frozen_string_literal: true

RSpec.describe PatchYAML do
  let(:value) do
    <<~YAML
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
  end
  let(:editor) { PatchYAML.load(value) }

  it "correctly updates without weirdnesses" do
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
end

# PatchYAML

PatchYAML is an utility library for patching YAML while optimistically keeping
the original document formatting.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add patchyaml
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install patchyaml
```

## Usage

The exposed interface is intentionally minimal. The library provide the methods
`delete`, `update`, `map_rename`, `map_add`, and `seq_add`, obtaining the
resulting changes through the `yaml` method. For instance:

```ruby
require 'patchyaml'

editor = PatchYAML.load(<<~YAML)
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

editor
  .delete("mapping.a.sequence.1")
  .update("mapping.a.sequence.3.otherValue", "henlo")
  .map_rename("mapping.b", to: "test")
  .map_add("mapping.a", "e", "some value")
  .seq_add("f", 123)

puts editor.yaml
# mapping:
#   a:
#     sequence:
#       - name: b
#       - name: c
#       - name: d
#         otherValue: henlo
#   b: test
#   c: true
#   d: [1, 2, 3, 4, foo, bar, hello]
#   e: some value
# d: 1
# empty:
# e: { a: 1, b: 2, c: 3 }
# f: [1, 2, 3, 4, hello, 123]
# g: {}
# h: []
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/heyvito/patchyaml. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/heyvito/patchyaml/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Patchyaml project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/heyvito/patchyaml/blob/master/CODE_OF_CONDUCT.md).

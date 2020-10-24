# Clicr

[![Build Status](https://cloud.drone.io/api/badges/j8r/clicr/status.svg)](https://cloud.drone.io/j8r/clicr)
[![ISC](https://img.shields.io/badge/License-ISC-blue.svg?style=flat-square)](https://en.wikipedia.org/wiki/ISC_license)

Command Line Interface for Crystal

A simple Command line interface builder which aims to be easy to use.

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  clicr:
    github: j8r/clicr
```

## Features

This library uses generics, thanks to Crystal's powerful type-inference, and few macros, to provide this following advantages:

- Compile time validation - methods must accept all possible options and arguments 
- No possible double commands/options at compile-time
- Declarative `NamedTuple` configuration
- Customizable configuration - supports all languages (See [Clicr.new](src/clicr.cr) parameters)
- Fast execution, limited runtime

## Usage

### Simple example

```crystal
require "clicr"

Clicr.new(
  label: "This is my app.",
  commands: {
    talk: {
      label:      "Talk",
      action:    {"CLI.say": "t"},
      arguments: %w(directory),
      options:   {
        name: {
          label:    "Your name",
          default: "foo",
        },
        no_confirm: {
          short: 'y',
          label:  "Print the name",
        },
      },
    },
  },
).run

module CLI
  def self.say(arguments, name, no_confirm)
    puts arguments, name, no_confirm
  end
end
```

Example of commands:
```
$ myapp --help
Usage: myapp COMMANDS [OPTIONS]

Myapp can do everything

COMMANDS
  t, talk   Talk

OPTIONS
  --name=foo         Your name
  -y, --no-confirm   Print the name

'myapp --help' to show the help.
```
```
$ myapp talk /tmp name=bar
no, bar in /tmp
```
```
$ myapp talk home name=bar -y
yes, bar in home
```
```
$ myapp talk test
no, foo in test
```

### Advanced example

See the  one in the [spec test](spec/clicr_spec.cr)

### CLI Composition

It's also possible to merge several commands or options together.

```crystal
other = {
  pp: {
    label: "It pp",
    action: "pp"
  }
}

Clicr.new(
  label: "Test app",
  commands: {
    puts: {
      alias: 'p',
      label: "It puts",
      action: "puts",
    }.merge(other) 
  }
)
```

Help output:
```
Usage: myapp COMMAND

Test app

COMMAND
  p, puts   It puts
  pp        It pp

'myapp --help' to show the help.
```

## Reference

### Commands

Example: `s`, `start`

```crystal
commands: {
  short: {
    action: { "say": "s" },
    label: "Starts the server",
    description: <<-E.to_s,
    This is a full multi-line description
    explaining the command
    E,
  }
}
```

* `action` is a `NamedTuple` with as key the method to call, and as a value a command alia, which can be empty for none.
* in `action`, parentheses can be added to determine the arguments placement, like `File.new().file`
* `label` is supposed to be short, one-line description
* `description` can be a multi-line description of the command. If not set, `label` will be used. 

### Arguments

Example: `command FooBar`, `command mysource mytarget`

```crystal
arguments: %w(directory names)
```

```crystal
arguments: {"source", "target"}
```

* if a `Tuple` is given, the arguments number **must** be exactly the `Tuple` size.
* if an `Array` is given, the arguments number must be at least, or more, the `Array` size

### Options

#### Boolean options

Example: `-y`, `--no-confirm`

```crystal
options: {
  no_confirm: {
    short: 'y',
    label: "No confirmations",
  }
}
```

* apply recursively to subcommands
* `short` creates a short alias of one character - must be a `Char`
* concatenating single characters arguments like `-Ry1` is possible

Special case: the `help_option`, which is set to `"help"` with the options `-h, --help` by default,
shows the help of the current (sub)command

#### String options

Example: `--name=foo`, or `--name foo`

```crystal
options: {
  name: {
    label: "This is your name",
    default: "Foobar",
  }
}
```

* by default, apply recursively to subcommands. Can be disabled with `inherit: false`
* a `default` value, which can be nil, is required to define the option as an option string.
* can only be `String` (because arguments passed as `ARGV` are `Array(String)`) - if others type are needed, the cast must be done after the `action` method call

## License

Copyright (c) 2020 Julien Reichardt - ISC License

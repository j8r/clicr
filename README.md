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

## Usage

This shard consists to one single macro `Clicr.create`, that expands to recursive `while` loops and `case` conditions.

All the CLI, including errors, can be translated in the language of choice, look at the parameters at `src/clir.cr`.

All the configurations are done in a `NamedTuple` like follow:

### Simple example

```crystal
require "clicr"

def run_cli
  Clicr.create(
    name: "myapp",
    info: "Myapp can do everything",
    commands: {
      talk: {
        alias: 't',
        info: "Talk",
        action: "say",
        arguments: %w(directory),
      },
    },
     variables: {
       name: {
         info: "Your name",
         default: "foo",
       },
     },
     options: {
       no_confirm: {
         short: 'y',
         info: "Print the name",
       }
     }
  )
end

def say(directory, name, no_confirm)
  if no_confirm
    puts "yes, #{name} in #{directory}"
  else
    puts "no, #{name} in #{directory}"
  end
end

run_cli
```

Example of commands:
```
$ myapp --help
Usage: myapp COMMAND [VARIABLES] [OPTIONS]

Myapp can do everything

COMMAND
  t, talk   Talk

VARIABLES
  name=foo   Your name

OPTIONS
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

There can have subcommands that have subcommands indefinitely with their options/variables.

Other parameters can be customized like names of sections, the `help_option` and `unknown` errors messages:

```crystal
require "clicr"

ARGV.replace %w(talk -j forename=Jack to_me)

def run_cli
  Clicr.create(
    name: "myapp",
    info: "Application default description",
    usage_name: "Usage: ",
    command_name: "COMMAND",
    options_name: "OPTIONS",
    variables_name: "VARIABLES",
    help: "to show the help.",
    help_option: "help",
    argument_required: "argument required",
    unknown_command: "unknown command",
    unknown_option: "unknown option",
    unknown_variable: "unknown variable",
    commands: {
      talk: {
        alias:   't',
        info:    "Talk",
        options: {
          joking: {
            short: 'j',
            info:  "Joke tone",
          },
        },
        variables: {
          forename: {
            default: "Foo",
            info:    "Specify your forename",
          },
          surname: {
            default: "Bar",
            info:    "Specify your surname",
          },
        },
        commands: {
          to_me: {
            info:    "Hey that's me!",
            action:  "tell",
            inherit: %w(forename surname joking),
          },
        },
      },
    }
  )
end

def tell(forename, surname, joking)
  if joking
    puts "Yo my best #{forename} #{surname} friend!"
  else
    puts "Hello #{forename} #{surname}."
  end
end

run_cli
```

Result: `Yo my best Jack Bar friend!`

### CLI Composition

It's also possible to merge several CLIs together

```crystal
macro cli(**new_commands)

def run
  Clicr.create(
    name: "myapp",
    info: "Test app",
    commands: {
      puts: {
        alias: 'p',
        info: "It puts",
        action: "puts",
      },
      {{**new_commands}}
    }
  )
end
run

end

cli(
  pp: {
    info: "It pp",
    action: "pp"
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
  start: {
    alias: 's',
    info: "Starts the server",
    description: <<-E.to_s,
    This is a full multi-line description
    explaining the command
    E,
    action: "say",
  }
}
```

* `alias` creates an alias of the command. The alias mustn't already exist
* in `action`, parentheses can be added to determine the arguments placement, like `File.new().file`
* `info` is supposed to be short, one-line description
* `description` can be a multi-line description of the command. If not set, `info` will be used. 

### Arguments

Example: `name`, `directory`

```crystal
arguments: %w(directory names...),
```

* list arguments required after the command in the following order
* when arguments are specified, unless when ending with `...`, they becomes **mandatory**
* if the last argument ends with `...`, it isn't mandatory and have a default empty `Array(String)` value. All following arguments will be appended to it

### Options

Example: `-y`, `--no-confirm`

```crystal
options: {
  no_confirm: {
    short: 'y',
    info: "No confirmations",
  }
}
```

* apply recursively to subcommands
* `short` creates a short alias of one character - must be a `Char`
* concatenating single characters arguments like `-Ry1` is possible

Special case, the `help_option`, which is set to `"help"` with the options `-h, --help` by default
* Shows the help of the current (sub)command
* has the priority over every other arguments including other options, commands and variables

### Variables

Example: `name=foo`

```crystal
variables: {
  name: {
    info: "This is your name",
    default: "Foobar",
  }
}
```

* apply recursively to subcommands
* can only be `String` (because arguments passed as `ARGV` are `Array(String)`) - if others type are needed, the cast must be done after the `action` method call
* if no `default` value is set, `nil` will be the default one
* underscores `_` will replaced by dashes `-` for the CLI option name. The underlying variable will still have underscores

### Variables and options inheritance

To include `myoption` and `myvar` to a command, add `inherit: %(myvar myoption)` to the command arguments.

## Error handling

When a command issued can't be performed, an exception is raised that can be either `Help`, `ArgumentRequired`, `UnknownCommand`, `UnknownOption` or `UnknownVariable` depending of the error cause.

You can catch this exceptions like this:

```crystal
def my_cli
  include Clicr
  create(
  ...
  )
rescue ex : Help
  puts ex; exit 0
rescue ex : ArgumentRequired | UnknownCommand | UnknownOption | UnknownVariable
  abort ex
rescue ex
  abort ex
end
```

## License

Copyright (c) 2018 Julien Reichardt - ISC License

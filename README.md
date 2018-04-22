# Clicr

Command Line Interface for Crystal

A simple Command line interface builder which aims to be easy to use.

## Installation

Add this block to your application's `shard.yml`:

```yaml
dependencies:
  clicr:
    github: j8r/clicr
```

## Usage

This shard consist to one single macro `Clicr.create`,that expand to recursive `case`.

All the CLI, including errors, can be translated in the language of choice, look at the parameters at `src/clir.cr`.

All the configurations are done in a `NamedTuple` like follow:

### Simple example

```crystal
require "clicr"

Clicr.create(
  name: "myapp",
  info: "Myapp can do everything",
  commands: {
    talk: {
      alias: true,
      info: "Talk",
      action: say,
    },
  },
   variables: {
     name: {
       default: "foo",
     },
   },
   options: {
     yes: {
       alias: true,
       info: "Print the name",
     }
   }
)

def say(name, yes)
  if yes
    puts "yes, "
  else
    puts "no, "
  end + name
end
```

Example of commands:
```sh
myapp talk name=bar    #=> no, bar

myapp talk name=bar -y #=> yes, bar

myapp talk             #=> no, foo
```

### Advanced example

There can have subcommands that have subcommands indefinitely with their options/variables.

Other parameters can be customized like names of sections, the `help_option` and `unknown` errors messages:

```crystal
ARGV.replace ["talk", "-j", "forename=Jack", "to_me"]

Clicr.create(
  name: "myapp",
  info: "Application default description",
  version: "Default version",
  version_name: "Version",
  usage_name: "Usage",
  commands_name: "Commands",
  options_name: "Options",
  variables_name: "Variables",
  help: "to show the help",
  help_option: "help",
  unknown_option: "Unknown option",
  unknown_command: "Unknown command or variable",
  unknown_variable: "Unknown variable",
  commands: {
    talk: {
      alias: true,
      info: "Talk",
      options: {
        joking: {
          alias: true,
          info: "Joke tone"
        }
      },
      variables: {
        forename: {
          default: "Foo",
          info: "Specify your forename",
        },
        surname: {
          default: "Bar",
          info: "Specify your surname",
        },
      },
      commands: {
        to_me: {
          info: "Hey that's me!",
          action: tell,
        },
      }
    }
  }
)


def tell(forename, surname, joking)
  if joking
     puts "Yo my best #{forename} #{surname} friend!"
  else
    puts "Hello #{forename} #{surname}."
  end
end
```

Result: `Yo my best Jack Bar friend!`


## Reference

### Commands

Example: `s`, `start`

```crystal
commands: {
  start: {
    info: "Starts the server",
    action: say,
  }
}
```

* `alias: true` create an alias with the first char of the commands, like `v` for `version`

### Options

Example: `-y`, `--yes`

```crystal
option: {
  yes: {
    alias: true,
    info: "No confirmations",
  }
}
```

* apply recursively to subcommands
* are only booleans, with `false` at default when not set
* `alias: true` create an alias with the first char of the option, like `-v` for `--version`
* containing single character arguments like `-` is possible

Special case, the `help_option` with by default `-h`, `--help` (`help_option = "help"`):
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
* can only be `String` (because arguments as `ARGV` passed are `Array(String)`) - if others type are needed, the cast must be done after the `action` method call
* if no `default` value is not set, `nil` will be the default one

## License

Copyright (c) 2018 Julien Reichardt - ISC License

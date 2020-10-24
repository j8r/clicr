class Clicr
  module Subcommand
  end
end

struct Clicr::Command(Action, Arguments, Commands, Options)
  include Clicr::Subcommand
  getter label, description, arguments, inherit, exclude, sub_commands, options

  struct Option
    getter short : Char?, label : String?, default : String?
    getter? string_option : Bool

    def initialize(@label : String?, @short : Char?, @default : String?, @string_option : Bool)
    end
  end

  private def initialize(
    @label : String?,
    @description : String?,
    @inherit : Array(String)?,
    @exclude : Array(String)?,
    @action : Action,
    @arguments : Arguments,
    @sub_commands : Commands,
    @options : Options
  )
  end

  def self.create(
    label : String? = nil,
    description : String? = nil,
    inherit : Array(String)? = nil,
    exclude : Array(String)? = nil,
    action : Action = nil,
    arguments : Arguments = nil,
    commands : Commands = nil,
    options : Options = nil
  )
    {% !(Action < NamedTuple) && Commands == Nil && raise "At least an action to perform or sub-commands that have actions to perfom is needed." %}
    new(
      label,
      description,
      inherit,
      exclude,
      action,
      arguments,
      commands,
      options,
    )
  end

  def each_sub_command(& : String, String, Subcommand ->)
    {% if Commands < NamedTuple %}
      {% for name, sub in Commands %}
      yield(
        {{name.stringify}},
        @sub_commands[{{name.symbolize}}][:action].values.first,
        Command.create(**@sub_commands[{{name.symbolize}}])
      )
      {% end %}
    {% end %}
  end

  def each_option(& : Char | String, Option ->)
    @options.try &.each do |name, opt|
      option = Option.new(
        label: opt[:label]?,
        short: opt[:short]?,
        default: opt[:default]?,
        string_option: opt.has_key?(:default)
      )
      yield name.to_s, option
      if short = option.short
        yield short, option
      end
    end
  end

  private def to_real_option(option : Char | String) : String
    option.is_a?(Char) ? "-#{option}" : "--#{option}"
  end

  # Executes an action, if availble.
  def exec(command_name : String, clicr : Clicr)
    {% begin %}
      {% options = Options < NamedTuple ? Options : {} of String => String %}
      {% for option, sub in options %}\
        {% if sub[:default] == Nil || sub[:default] %}\
          __{{option}} = @options[{{option.symbolize}}][:default]
        {% else %}\
          __{{option}} = false
        {% end %}\
      {% end %}\

      name_with_command = clicr.parse_options command_name, self do |option_name, value|
        case option_name
        {% for option, sub in options %}\
        when {{option.stringify}} {% if sub[:short] %}, @options[{{option.symbolize}}][:short] {% end %}
          {% if sub[:default] == Nil || sub[:default] %}
            if value.is_a? String
               __{{option}} = value              
            elsif next_value = clicr.args.shift?
               __{{option}} = next_value
            else
              return clicr.error_callback.call(
                clicr.argument_required.call(command_name, to_real_option(option_name)) + clicr.help_footer.call(command_name)
              )
            end
          {% else %}
            __{{option}} = true
          {% end %}
        {% end %}
        else
          return clicr.error_callback.call(
            clicr.unknown_option.call(command_name, to_real_option(option_name)) + clicr.help_footer.call(command_name)
          )
        end
      end

      if name_with_command.is_a? Tuple(String, Subcommand)
        return name_with_command[1].exec(name_with_command[0], clicr)
      elsif !name_with_command.is_a? Clicr
        # a callback has been called, stop
        return
      end
      
    {% if Action < NamedTuple %}
      {% action = Action.keys[0].split("()") %}
      {{ action[0].id }}(
        {% if Arguments < Tuple %}
          arguments: Arguments.from(clicr.arguments)
        {% elsif Arguments < Array %}
          arguments: clicr.arguments,
        {% end %}
        {% for option, type in options %}\
          {{option}}: __{{option}},
        {% end %}
      ){% if action.size > 1 %}{{ action[1].id }}{% end %}
    {% else %}
      clicr.help command_name, self
    {% end %}
    {% end %}
  end
end

class Clicr
  module Subcommand
  end
end

struct Clicr::Command(Action, Arguments, Commands, Options)
  include Clicr::Subcommand
  getter name, short, label, description, arguments, inherit, exclude, sub_commands, options

  struct Option(T, D)
    getter short : Char?,
      label : String?,
      default : D,
      type : T.class = T
    getter? string_option : Bool = false

    private def initialize(@label, @short, @type : T.class, @default : D, @string_option)
    end

    def self.new(label : String? = nil, short : Char? = nil)
      new label, short, Nil, nil, false
    end

    def self.new(type : T.class, label : String? = nil, short : Char? = nil)
      new label, short, type, nil, true
    end

    def self.new(default : D, label : String? = nil, short : Char? = nil)
      new label, short, D, default, true
    end

    # yields in cast of
    def cast_value(raw_value : String) : T
      {% if T == String %}
        raw_value
      {% else %}
        T.new raw_value
      {% end %}
    end
  end

  private def initialize(
    @name : String,
    @short : String?,
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
    name : String,
    short : String,
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
    {% if Options < NamedTuple %}
      casted_options = {
      {% for name in Options.keys.sort_by { |k| k } %}\
        # {{name}}
        {{name.stringify}}: Option.new(**options[{{name.symbolize}}]),
      {% end %}
      }
    {% else %}
      casted_options = nil
    {% end %}
    {% if Commands < NamedTuple %}
      casted_commands = {
      {% for name in Commands.keys.sort_by { |k| k } %}\
      create(
        **commands[{{name.symbolize}}].merge({
          name: {{name.stringify}},
          short: commands[{{name.symbolize}}][:action].values.first
        })
      ),
      {% end %}
      }
    {% else %}
      casted_commands = nil
    {% end %}
    {% begin %}
      new(
        name,
        (short if !short.empty?),
        label,
        description,
        inherit,
        exclude,
        action,
        arguments,
        casted_commands,
        casted_options
      )
    {% end %}
  end

  private def to_real_option(option : Char | String) : String
    option.is_a?(Char) ? "-#{option}" : "--#{option}"
  end

  # Executes an action, if availble.
  def exec(command_name : String, clicr : Clicr)
    {% begin %}
      {% options = Options < NamedTuple ? Options : {} of String => String %}
      {% for option, sub in options %}\
        # {{option}}
        {% if sub.type_vars.first == Nil %}\
          %options{option} = false
        {% else %}
          %options{option} = @options[{{option.symbolize}}].default
        {% end %}\
      {% end %}\

      sub_command = clicr.parse_options command_name, self do |option_name, value|
        case option_name
        {% for option, sub in options %}\
        when {{option.stringify}}, @options[{{option.symbolize}}].short
          {% if sub.type_vars.first == Nil %}
            %options{option} = true
          {% else %}
            raw_value = value.is_a?(String) ? value : clicr.args.shift?

            if raw_value
              begin
                %options{option} = @options[{{option.symbolize}}].cast_value raw_value
              rescue ex
                return clicr.error_callback.call(
                  clicr.invalid_option_value.call(
                    command_name, to_real_option(option_name), ex
                  ) + clicr.help_footer.call(command_name)
                )
              end
            else
              return clicr.error_callback.call(
                clicr.argument_required.call(command_name, to_real_option(option_name)) + clicr.help_footer.call(command_name)
              )
            end
          {% end %}
        {% end %}
        else
          return clicr.error_callback.call(
            clicr.unknown_option.call(command_name, to_real_option(option_name)) + clicr.help_footer.call(command_name)
          )
        end
      end

      if sub_command.is_a? Subcommand
        return sub_command.exec("#{command_name} #{sub_command.name}", clicr)
      elsif !sub_command.is_a? Clicr
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
        {% for option, sub in options %}\
          {{option.gsub(/-/, "_")}}: %options{option},
        {% end %}
      ){% if action.size > 1 %}{{ action[1].id }}{% end %}
    {% else %}
      clicr.help command_name, self
    {% end %}
    {% end %}
  end
end

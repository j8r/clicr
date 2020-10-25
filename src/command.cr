class Clicr
  module Subcommand
  end
end

struct Clicr::Command(Action, Arguments, Commands, Options)
  include Clicr::Subcommand
  getter label, description, arguments, inherit, exclude, sub_commands, options

  struct Option(T)
    getter short : Char?,
      label : String?,
      default : T? = nil,
      type : T.class = T
    getter? string_option : Bool = false

    private def initialize(@label, @short, @type : T.class, @string_option)
    end

    def self.new(label : String? = nil, short : Char? = nil)
      new label, short, Nil, false
    end

    def initialize(@type : T.class, @label : String? = nil, @short : Char? = nil)
      @string_option = true
    end

    def initialize(@default : T, @label : String? = nil, @short : Char? = nil)
      @string_option = true
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

  def each_option(& : Char | String ->)
    {% if Options < NamedTuple %}
      {% for name, opt in Options %}
        # {{name}}
        %name = Option.new(**@options[{{name.symbolize}}])
        yield {{name.stringify}}, %name
        if short = %name.short
          yield short, %name
        end
      {% end %}
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
        {% if sub[:default] %}\
          %options{option} = @options[{{option.symbolize}}][:default]
        {% elsif sub[:type] %}\
          %options{option} = nil
        {% else %}
          %options{option} = false
        {% end %}\
      {% end %}\

      name_with_command = clicr.parse_options command_name, self do |option_name, value|
        case option_name
        {% for option, sub in options %}\
        when {{option.stringify}} {% if sub[:short] %}, @options[{{option.symbolize}}][:short] {% end %}
          {% type = sub[:type] ? sub[:type].name.split(".class")[0] : sub[:default].stringify %}
          {% if type != "nil" %}
            raw_value = value.is_a?(String) ? value : clicr.args.shift?

            if raw_value
              {% if type == "String" %}
              %options{option} = raw_value
              {% else %}
              begin
                %options{option} = {{type.id}}.new raw_value
              rescue ex
                return clicr.error_callback.call(
                  clicr.invalid_option_value.call(
                    command_name, to_real_option(option_name), ex
                  ) + clicr.help_footer.call(command_name)
                )
              end
              {% end %}
            else
              return clicr.error_callback.call(
                clicr.argument_required.call(command_name, to_real_option(option_name)) + clicr.help_footer.call(command_name)
              )
            end
          {% else %}
            %options{option} = true
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
          {{option.gsub(/-/, "_")}}: %options{option},
        {% end %}
      ){% if action.size > 1 %}{{ action[1].id }}{% end %}
    {% else %}
      clicr.help command_name, self
    {% end %}
    {% end %}
  end
end

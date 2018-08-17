module Clicr
  {% for exception in %w(Help ArgumentRequired UnknownCommandOrVariable UnknownOption) %}
  class {{exception.id}} < Exception
  end
  {% end %}

  macro create(
    name = "app",
    info = "Application's description",
    usage_name = "Usage",
    commands_name = "Commands",
    options_name = "Options",
    variables_name = "Variables",
    help = "to show the help",
    help_option = "help",
    argument_required = "requires at least one argument",
    unknown_option = "unknown option",
    unknown_command_or_variable = "unknown command or variable",
    action = nil,
    commands = NamedTupleLiteral,
    arguments = ArrayLiteral,
    options = NamedTupleLiteral,
    variables = NamedTupleLiteral
  )
  # {{name}}
  # Needed to have variables "namespaced"
  1.times do
    # Initialize default values
  {% if variables.is_a? NamedTupleLiteral %}{% for var, properties in variables %}\
    {% if !properties[:initialized] %}
    {{var}} = {{properties[:default]}}
    {% end %}{% end %}{% end %}\
  {% if options.is_a? NamedTupleLiteral %}{% for var, properties in options %}\
    {{var}} = false
  {% end %}{% end %}

  # Parse arguments
  {% if arguments.is_a? ArrayLiteral %}
    {% for arg in arguments %}\
      # Array arguments
      {% if arg.ends_with? "..." %}
        {{arg[0..-4].id}} = Array(String).new
      # Simple arguments
      {% else %}
        {{arg.id}} = ""
        case arg = ARGV.first?
        when nil
          raise Clicr::ArgumentRequired.new "{{name.id}}: {{arg.id.upcase}}: {{argument_required.id}}\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
        when "", "--{{help_option.gsub(/_/, "-").id}}", "-{{help_option.chars.first.id}}"
        else
          {{arg.id}} = arg
          ARGV.shift
        end
      {% end %}
    {% end %}
  {% end %}

  # Print help if there are required following commands
  {% if commands.is_a? NamedTupleLiteral %}
    ARGV << "" if ARGV.empty?
  {% end %}

  # Loop while there are argument
    while !ARGV.empty?

      # An action or subcommands are needed
      {% if !action && !commands.is_a?(NamedTupleLiteral) %}{{raise "You need at least an action to perform for #{name}, or subcommands that have actions to perfom"}}{% end %}

      case ARGV.first
        # Generate commands match
      {% if commands.is_a? NamedTupleLiteral %}{% for subcommand, properties in commands %}
      when "{{subcommand}}"{% if properties[:alias] %}, "{{properties[:alias].id}}"{% end %}

        # Remove the command executed
        ARGV.shift?

        # Options are variables that apply recursively to subcommands
        Clicr.create(
          "{{name.id}} {{subcommand.id}}", {{properties[:info]}}, {{usage_name}}, {{commands_name}}, {{options_name}}, {{variables_name}}, {{help}}, {{help_option}}, {{argument_required}}, {{unknown_option}}, {{unknown_command_or_variable}}, {{properties[:action]}}, {{properties[:commands]}}, {{properties[:arguments]}},
          # ":initialized" is used to tell that the variable is declared, and not declare it again (thus override it) in further blocks
          # Merge options for recursive use in subcommands
          {% if options.is_a? NamedTupleLiteral || properties[:options].is_a? NamedTupleLiteral %}
            options: { {% if options.is_a? NamedTupleLiteral %}
              {% for option, values in options %}{% values[:initialized] = true %} {{option}}: {{values}},{% end %}
            {% end %}{% if properties[:options].is_a? NamedTupleLiteral %}
              {% for subcommand, values in properties[:options] %}{{subcommand}}: {{values}},{% end %}
            {% end %} },
          {% end %}
          # Merge variables for recursive use in subcommands
          {% if variables.is_a? NamedTupleLiteral || properties[:variables].is_a? NamedTupleLiteral %}
            variables: { {% if variables.is_a? NamedTupleLiteral %}
              {% for var, values in variables %}{% values[:initialized] = true %} {{var}}: {{values}},{% end %}
            {% end %}{% if properties[:variables].is_a? NamedTupleLiteral %}
              {% for var, values in properties[:variables] %}{{var}}: {{values}},{% end %}
            {% end %} },
          {% end %}
        )
      {% end %} {% end %}
        # Help
      when "", "--{{help_option.id}}", "-{{help_option.chars.first.id}}"
        raise Clicr::Help.new(
        <<-HELP
        {{usage_name.id}}: {{name.id}}\
        {% if arguments.is_a? ArrayLiteral %} {{arguments.join(' ').upcase.id}}{% end %}\
        {% if commands.is_a? NamedTupleLiteral %} {{commands_name.upcase.id}}{% end %}\
        {% if variables.is_a? NamedTupleLiteral %} [{{variables_name.upcase.id}}]{% end %}\
        {% if options.is_a? NamedTupleLiteral %} [{{options_name.upcase.id}}]{% end %}

        {{info.id}}
        {% if options.is_a? NamedTupleLiteral %}
        {{options_name.id}}:{% for opt, value in options %}
          {% if value[:short].is_a? CharLiteral %}\
            -{{value[:short].id}}, \
          {% else %}    \
          {% end %}\
          --{{opt.gsub(/_/, "-")}} \t {{value[:info].id}}\
        {% end %}
        {% end %}\
        {% if variables.is_a? NamedTupleLiteral %}
        {{variables_name.id}}:{% for var, value in variables %}
          {{var}}{% if value[:default] %}=#{{{value[:default]}}}{% else %}\t{% end %} \t {{value[:info].id}}\
        {% end %}
        {% end %}\
        {% if commands.is_a? NamedTupleLiteral %}
        {{commands_name.id}}:{% for command, value in commands %}
          {% if value[:alias] %}\
            {{value[:alias].id}}, \
        {% else %}\
        {% end %}{{command}} \t {{value[:info].id}}\
        {% end %}
        {% end %}
        '{{name.id}} --{{help_option.id}}' {{help.id}}
        HELP
        )
      # Generate variables match
      {% if variables.is_a? NamedTupleLiteral %}{% for var, value in variables %}
      when .starts_with? "{{var}}="
          {{var}} = ARGV.first[{{var.size + 1}}..-1]
      {% end %}{% end %}

        # Generate options match
      {% if options.is_a? NamedTupleLiteral %}{% for opt, value in options %}
      when "--{{opt.gsub(/_/, "-").id}}" then {{opt}} = true {% end %}{% end %}

      when .starts_with? "--"  then raise Clicr::UnknownOption.new "{{name.id}}: {{unknown_option.id}}: '#{ARGV.first}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
      when .starts_with? '-'
        # Parse options
        ARGV.first.lchop.each_char do |opt|
          {% if options.is_a? NamedTupleLiteral %}
          case opt
          {% for opt, value in options %}
          {% if value[:short].is_a? CharLiteral %} when {{value[:short]}}
            {{opt}} = true
            next
          {% end %}{% end %}
          end {% end %}
          # Invalid option
          raise Clicr::UnknownOption.new "{{name.id}}: {{unknown_option.id}}: '-#{opt}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
        end

      {% if arguments.is_a? ArrayLiteral && arguments[-1].ends_with? "..." %}
      else
        {{arguments[-1][0..-4].id}} << ARGV.first
      {% else %}
        # Exceptions
      else
          raise Clicr::UnknownCommandOrVariable.new "{{name.id}}: {{unknown_command_or_variable.id}}: '#{ARGV.first}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
      {% end %}
      end
      ARGV.shift?
    end

    # At the end execute the command {{name}}
    {% if action %}
      {{action.split("()")[0].id}}({% if variables.is_a? NamedTupleLiteral %}\
         {% for var, _x in variables %}
         {{var.id}}: {{var.id}},{% end %}{% end %}\
      {% if options.is_a? NamedTupleLiteral %}
         {% for opt, _x in options %}{{opt.id}}: {{opt.id}},
      {% end %}{% end %}\
      {% if arguments.is_a? ArrayLiteral %}\
        {% for arg in arguments %}\
          {% if arg.ends_with? "..." %}\
            {{arg[0..-4].id}}: {{arg[0..-4].id}},
          {% else %}\
            {{arg.id}}: {{arg.id}},
        {% end %}\
      {% end %}{% end %}){% if action.split("()")[1] %}{{action.split("()")[1].id}}{% end %}
    {% end %}
    end
  end
end

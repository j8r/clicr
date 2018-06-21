module Clicr
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
    unknown_command_variable = "unknown command or variable",
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
        if ARGV.first?
          # Append following arguments
          while !ARGV.empty?
            case arg = ARGV.first
            when "", .starts_with? '-'
              break
            else
              {{arg[0..-4].id}} << arg
              ARGV.shift
            end
          end
        end
      # Simple arguments
      {% else %}
        {{arg.id}} = ""
        case arg = ARGV.first?
        when nil
          raise Exception.new("{{name.id}}: {{arg.id.upcase}}: {{argument_required.id}}\n'{{name.id}} --{{help_option.id}}' {{help.id}}", Exception.new "argument_required")
        when "", "--{{help_option.id}}", "-{{help_option.chars.first.id}}"
        else
          {{arg.id}} = arg
          ARGV.shift
        end
      {% end %}
    {% end %}
  {% end %}

  # Loop while there are argument
    while !ARGV.empty?

      # An action or subcommands are needed
      {% if !action && !commands.is_a?(NamedTupleLiteral) %}{{raise "You need at least an action to perform for #{name}, or subcommands that have actions to perfom"}}{% end %}

      case ARGV.first
        # Generate commands match
      {% if commands.is_a? NamedTupleLiteral %}{% for subcommand, properties in commands %}
      when "{{subcommand}}" \
        {% if properties[:alias] %} \
            , "{{properties[:alias].id}}" \
        {% end %}

        # Check if the required arguments are present
        {% if properties[:arguments].is_a? ArrayLiteral %}
          {% for arg in properties[:arguments] %}\
            {% if arg.ends_with? "..." %}
              {{arg[0..-4].id}} = Array(String).new
            {% else %}
              if ARGV.size == 1
                raise Exception.new("{{name.id}} {{subcommand.id}} {{arg.id.upcase}} - {{argument_required.id}}\n'{{name.id}} --{{help_option.id}}' {{help.id}}", Exception.new "argument_required")
              end
              {{arg.id}} = ""
            {% end %}
          {% end %}
          # Print the help
          ARGV.replace ["", ""] if ARGV.size == 1
        {% end %}

        # Perform action for {{name.id}} {{subcommand.id}} if no more arguments
        {% if properties[:action] %}
        if ARGV.size == 1
          {{properties[:action].id}}({% if variables.is_a? NamedTupleLiteral %}\
             {% for var, _x in variables %}{{var.id}}: {{var.id}},
          {% end %}{% end %}\
          {% if options.is_a? NamedTupleLiteral %}\
             {% for opt, _x in options %}{{opt.id}}: {{opt.id}},
          {% end %}{% end %}\
          {% if properties[:arguments].is_a? ArrayLiteral %}\
            {% for arg in properties[:arguments] %}
            {% if arg.ends_with? "..." %}\
              {{arg[0..-4].id}}: {{arg[0..-4].id}},
            {% else %}\
              {{arg.id}}: {{arg.id}},
            {% end %}\
          {% end %}{% end %})
        else
        {% end %}

        # Remove the command executed
        ARGV.shift?

        # Options are variables that apply recursively to subcommands
        Clicr.create(
          "{{name.id}} {{subcommand.id}}", {{properties[:info]}}, {{usage_name}}, {{commands_name}}, {{options_name}}, {{variables_name}}, {{help}}, {{help_option}}, {{argument_required}}, {{unknown_option}}, {{unknown_command_variable}}, {{properties[:action]}}, {{properties[:commands]}}, {{properties[:arguments]}},
          # ":initialized" is used to tell that the variable is declared, and not declare it again (thus override it) in further blocks
          # Merge options for recursive use in subcommands
          {% if options.is_a? NamedTupleLiteral || properties[:options].is_a? NamedTupleLiteral %}
            options: { {% if options.is_a? NamedTupleLiteral %}
              {% for option, values in options %}{% values[:initialized] = true %} {{option.id}}: {{values.id}},{% end %}
            {% end %}{% if properties[:options].is_a? NamedTupleLiteral %}
              {% for subcommand, values in properties[:options] %}{{subcommand.id}}: {{values.id}},{% end %}
            {% end %} },
          {% end %}
          # Merge variables for recursive use in subcommands
          {% if variables.is_a? NamedTupleLiteral || properties[:variables].is_a? NamedTupleLiteral %}
            variables: { {% if variables.is_a? NamedTupleLiteral %}
              {% for var, values in variables %}{% values[:initialized] = true %} {{var.id}}: {{values.id}},{% end %}
            {% end %}{% if properties[:variables].is_a? NamedTupleLiteral %}
              {% for var, values in properties[:variables] %}{{var.id}}: {{values.id}},{% end %}
            {% end %} },
          {% end %}
        )
        {% if properties[:action] %}end{% end %}
        # action executed - nothing to parse anymore
        ARGV.clear
      {% end %}{% end %}

        # Help
      when "", "--{{help_option.id}}", "-{{help_option.chars.first.id}}"{% if action == nil %}, ARGV.last{% end %}
        raise Exception.new(
        <<-HELP
        {{usage_name.id}}: {{name.id}}\
        {% if arguments.is_a? ArrayLiteral %} {{arguments.join(' ').id.upcase}}{% end %}\
        {% if commands.is_a? NamedTupleLiteral %} {{commands_name.id.upcase}}{% end %}\
        {% if variables.is_a? NamedTupleLiteral %} [{{variables_name.id.upcase}}]{% end %}\
        {% if options.is_a? NamedTupleLiteral %} [{{options_name.id.upcase}}]{% end %}

        {{info.id}}
        {% if options.is_a? NamedTupleLiteral %}
        {{options_name.id}}:{% for opt, value in options %}
          {% if value[:short].is_a? CharLiteral %}\
            -{{value[:short].id}}, \
          {% else %}    \
          {% end %}\
          --{{opt}} \t {{value[:info].id}}\
        {% end %}
        {% end %}\
        {% if variables.is_a? NamedTupleLiteral %}
        {{variables_name.id}}:{% for var, value in variables %}
          {{var}}={{value[:default].id}} \t {{value[:info].id}}\
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
        , Exception.new "help")
        # Generate options match
      {% if options.is_a? NamedTupleLiteral %}{% for opt, value in options %}
      when "--{{opt}}" \
        {% if value[:short].is_a? CharLiteral %} \
            , "-{{value[:short].id}}" \
        {% end %}
          {{opt}} = true
      {% end %}{% end %}

      # Generate variables match
      {% if variables.is_a? NamedTupleLiteral %}{% for var, value in variables %}
      when .starts_with? "{{var}}="
          {{var}} = ARGV.first[{{var.size + 1}}..-1]
      {% end %}{% end %}

        # Exceptions
      when .starts_with? "--"  then raise Exception.new("{{name.id}}: {{unknown_option.id}}: '#{ARGV.first}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}", Exception.new "unknown_option")
      when .starts_with? '-'
        # Invalid option
        raise Exception.new("{{name.id}}: {{unknown_option.id}}: '#{ARGV.first}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}", Exception.new "unknown_option") if ARGV.first.size == 2
        # Multi options
        ARGV.first.lchop.each_char { |opt| ARGV.insert 0, "-#{opt}" }

      else
        raise Exception.new("{{name.id}}: {{unknown_command_variable.id}}: '#{ARGV.first}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}", Exception.new "unknown_command_variable")
      end
      ARGV.shift?
    end

    # At the end execute the command {{name}}
    {% if action != nil %}
      {{action.id}}({% if variables.is_a? NamedTupleLiteral %}\
         {% for var, _x in variables %}{{var.id}}: {{var.id}},
      {% end %}{% end %}\
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
      {% end %}{% end %})
    {% end %}
    end
  end
end

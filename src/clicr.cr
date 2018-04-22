module Clicr
  macro create(
    name = File.basename(__FILE__),
    info = "Application default description",
    version = "Default version",
    version_name = "Version",
    usage_name = "Usage",
    commands_name = "Commands",
    options_name = "Options",
    variables_name = "Variables",
    help = "to show the help",
    help_option = "help",
    unknown_option = "Unknown option",
    unknown_command = "Unknown command or variable",
    unknown_variable = "Unknown variable",
    args = ARGV,
    action = nil,
    commands = NamedTupleLiteral,
    options = NamedTupleLiteral,
    variables = NamedTupleLiteral,
  )
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

  # Loop while there are argument
    while !ARGV.empty?

      # An action or subcommands are needed
      {% if !action && !commands.is_a?(NamedTupleLiteral) %}{{raise "You need at least an action to perform for #{name}, or subcommands that have actions to perfom"}}{% end %}

      case ARGV.first
        # Generate commands match
      {% if commands.is_a? NamedTupleLiteral %}{% for key, properties in commands %}
      when "{{key}}" \
        {% if properties[:alias] == true %} \
            , "{{key.chars.first.id}}" \
        {% end %}

        # Perform action for {{name.id}} {{key.id}} if no more arguments
        {% if properties[:action] %}
        if ARGV.size == 1
          {{properties[:action].id}}({% if variables.is_a? NamedTupleLiteral %}
             {% for var, x in variables %}{{var.id}}: {{var.id}},
          {% end %}
          {% if options.is_a? NamedTupleLiteral %}
             {% for opt, x in options %}{{opt.id}}: {{opt.id}},
          {% end %}{% end %}{% end %})
        end
        {% end %}

        ARGV.shift

        # Options are variables apply recursively to subcommands
        Clicr.create(
          "{{name.id}} {{key.id}}", {{info}}, {{version}}, {{version_name}}, {{usage_name}}, {{commands_name}}, {{options_name}}, {{variables_name}}, {{help}}, {{help_option}}, {{unknown_option}}, {{unknown_command}}, {{unknown_variable}},
          commands: {{properties[:commands]}},
          action: {{properties[:action]}},
          # Merge options for recursive use in subcommands
          {% if options.is_a? NamedTupleLiteral || properties[:options].is_a? NamedTupleLiteral %}
            options: { {% if options.is_a? NamedTupleLiteral %}
              {% for key, values in options %}{% values[:initialized] = true %} {{key.id}}: {{values.id}},{% end %}
            {% end %}{% if properties[:options].is_a? NamedTupleLiteral %}
              {% for key, values in properties[:options] %}{{key.id}}: {{values.id}},{% end %}
            {% end %} },
          {% end %}
          # Merge variables for recursive use in subcommands
          {% if variables.is_a? NamedTupleLiteral || properties[:variables].is_a? NamedTupleLiteral %}
            variables: { {% if variables.is_a? NamedTupleLiteral %}
              {% for key, values in variables %}{% values[:initialized] = true %} {{key.id}}: {{values.id}},{% end %}
            {% end %}{% if properties[:variables].is_a? NamedTupleLiteral %}
              {% for key, values in properties[:variables] %}{{key.id}}: {{values.id}},{% end %}
            {% end %} },
          {% end %}
        )

        break
      {% end %}{% end %}

        # Help
      when "", "--{{help_option.id}}", "-{{help_option.chars.first.id}}"{% if action == nil %}, ARGV.last{% end %}
        puts <<-HELP
        {{usage_name.id}}: {{name.id}} COMMAND [OPTIONS]

        {{info.id}}
        {% if options.is_a? NamedTupleLiteral %}
        {{options_name.id}}:{% for key, value in options %}
          {% if value[:alias] == true %}\
            -{{key.chars.first.id}}, \
          {% else %}    \
          {% end %}\
          --{{key}} \t {{value[:info].id}}\
        {% end %}
        {% end %}\
        {% if variables.is_a? NamedTupleLiteral %}
        {{variables_name.id}}:{% for key, value in variables %}
          {{key}}={{value[:default].id}} \t {{value[:info].id}}\
        {% end %}
        {% end %}\
        {% if commands.is_a? NamedTupleLiteral %}
        {{commands_name.id}}:{% for key, value in commands %}
          {% if value[:alias] == true %}\
            {{key.chars.first.id}}, \
        {% else %}\
        {% end %}{{key}} \t {{value[:info].id}}\
        {% end %}
        {% end %}
        '{{name.id}} --{{help_option.id}}' {{help.id}}


        HELP
        exit 0
        # Generate options match
      {% if options.is_a? NamedTupleLiteral %}{% for key, value in options %}
      when "--{{key}}" \
        {% if value[:alias] == true %} \
            , "-{{key.chars.first.id}}" \
        {% end %}
          {{key}} = true
      {% end %}{% end %}

      # Generate variables match
      {% if variables.is_a? NamedTupleLiteral %}{% for key, value in variables %}
      when .starts_with? "{{key}}="
          {{key}} = ARGV.first[{{key.size + 1}}..-1]
      {% end %}{% end %}

        # Exceptions
      when .starts_with? "--"  then raise "{{unknown_option.id}}: '#{ARGV}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
      when .starts_with? '-'
        # Invalid option
        raise "{{unknown_option.id}}: '#{ARGV}'\n'{{name.id}} -{{help_option.id}}' {{help.id}}" if ARGV.first.size == 2
        # Multi options
        ARGV.first.lchop.each_char { |opt| ARGV.insert 0, "-#{opt}" }

      else
        raise "{{unknown_command.id}}: '#{ARGV.first}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
      end

      # At the end execute the command {{name}}
      {% if action != nil %}
        if ARGV.size == 1
          {{action.id}}({% if variables.is_a? NamedTupleLiteral %}
             {% for var, x in variables %}{{var.id}}: {{var.id}},
          {% end %}
          {% if options.is_a? NamedTupleLiteral %}
             {% for opt, x in options %}{{opt.id}}: {{opt.id}},
          {% end %}{% end %}{% end %})
        end
      {% end %}

      ARGV.shift
    end
  end
  end
end

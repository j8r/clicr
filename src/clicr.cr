module Clicr
  {% for exception in %w(Help ArgumentRequired UnknownCommand UnknownOption UnknownVariable) %}
  class {{exception.id}} < Exception
  end
  {% end %}

  macro create(
    name = "app",
    info = nil,
    description = nil,
    usage_name = "Usage: ",
    command_name = "COMMAND",
    options_name = "OPTIONS",
    variables_name = "VARIABLES",
    help = "to show the help.",
    help_option = "help",
    argument_required = "argument required",
    unknown_command = "unknown command",
    unknown_option = "unknown option",
    unknown_variable = "unknown variable",
    action = nil,
    commands = NamedTupleLiteral,
    arguments = ArrayLiteral,
    options = NamedTupleLiteral,
    variables = NamedTupleLiteral
  )
    # {{name}} help
    help = -> () do
      raise Clicr::Help.new(
        String.build do |str|
          str << <<-%HEADER
          {{usage_name.id}}{{name.id}}\
          {% if arguments.is_a? ArrayLiteral %} {{arguments.join(' ').upcase.id}}{% end %}\
          {% if commands.is_a? NamedTupleLiteral %} {{command_name.upcase.id}}{% end %}\
          {% if variables.is_a? NamedTupleLiteral %} [{{variables_name.upcase.id}}]{% end %}\
          {% if options.is_a? NamedTupleLiteral %} [{{options_name.upcase.id}}]{% end %}
          %HEADER
          {% if description || info %}
          str << "\n\n" << {{ description || info }}
          {% end %}

          {% if commands.is_a? NamedTupleLiteral %}
          str << "\n\n{{command_name.id}}"
          str << Clicr.align(str, {
          {% for command, value in commands %}
            { "{% if value[:alias] %}\
            {{value[:alias].id}}, \
            {% end %}{{command.id}}", {{value[:info]}} },
          {% end %} })
          {% end %}

          {% if variables.is_a? NamedTupleLiteral %}
          str << "\n\n{{variables_name.id}}"
          str << Clicr.align(str, {
          {% for var, value in variables %}\
            { %({{var.id}}{% if value[:default] %}=#{{{value[:default]}}}\
            {% end %}), {{value[:info]}} },
          {% end %} })
          {% end %}

          {% if options.is_a? NamedTupleLiteral %}
          str << "\n\n{{options_name.id}}"
          str << Clicr.align(str, {
          {% for opt, value in options %}
            { "{% if value[:short].is_a? CharLiteral %}\
            -{{value[:short].id}}, \
            {% else %}    \
            {% end %}\
            --{{opt.gsub(/_/, "-").id}}", {{value[:info]}} },
          {% end %} })
          {% end %}

          str << "\n\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
        end
      )
    end

    # Initialize default values
    {% if variables.is_a? NamedTupleLiteral %}{% for var, properties in variables %}\
      {% if !properties[:initialized] %}\
      __{{var.id}} = {{properties[:default]}}
      {% end %}{% end %}{% end %}\
    {% if options.is_a? NamedTupleLiteral %}{% for var, properties in options %}\
      __{{var.id}} = false
    {% end %}{% end %}

    # Parse arguments
    {% if arguments.is_a? ArrayLiteral %}
    {% for arg in arguments %}\
    {% if arg.ends_with? "..." %}\
      # Array argument
      __{{arg[0..-4].id}} = Array(String).new
    {% else %}\
    # Simple argument
    __{{arg.id}} = ""
    case arg = ARGV.first?
    when nil
      raise Clicr::ArgumentRequired.new "'{{name.id}}': {{argument_required.id}}: {{arg.upcase.id}}\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
    when "", "--{{help_option.gsub(/_/, "-").id}}", "-{{help_option.chars.first.id}}" then help.call
    else
      __{{arg.id}} = arg
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
      when "{{subcommand}}"{% if properties[:alias] %}, "{{properties[:alias].id}}"{% end %}
        # Remove the command executed
        ARGV.shift?

        # Options are variables that apply recursively to subcommands
        Clicr.create(
          "{{name.id}} {{subcommand.id}}", {{properties[:info]}}, {{properties[:description]}}, {{usage_name}}, {{command_name}}, {{options_name}}, {{variables_name}}, {{help}}, {{help_option}}, {{argument_required}}, {{unknown_command}}, {{unknown_option}}, {{unknown_variable}}, {{properties[:action]}}, {{properties[:commands]}}, {{properties[:arguments]}},
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
      {% end %}{% end %}
        # Help
      when "", "--{{help_option.id}}", "-{{help_option.chars.first.id}}" then help.call
      # Generate variables match
      {% if variables.is_a? NamedTupleLiteral %}{% for var, value in variables %}\
      when .starts_with? "{{var}}=" then __{{var.id}} = ARGV.first[{{var.size + 1}}..-1]
      {% end %}{% end %}

        # Generate options match
      {% if options.is_a? NamedTupleLiteral %}{% for opt, value in options %}\
      when "--{{opt.gsub(/_/, "-").id}}" then __{{opt.id}} = true {% end %}{% end %}

      when .starts_with? "--"  then raise Clicr::UnknownOption.new "{{name.id}}: {{unknown_option.id}}: '#{ARGV.first}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
      when .starts_with? '-'
        # Parse options
        ARGV.first.lchop.each_char do |opt_char|
        {% if options.is_a? NamedTupleLiteral %}
          case opt_char
          {% for opt, value in options %}\
          {% if value[:short].is_a? CharLiteral %} when {{value[:short]}}
            __{{opt.id}} = true
            next
          {% end %}{% end %}
          end
        {% end %}
          # Invalid option
          raise Clicr::UnknownOption.new "{{name.id}}: {{unknown_option.id}}: '-#{opt_char}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
        end

      # Custom handling of all the next arguments
      {% if arguments.is_a? ArrayLiteral && arguments[-1].ends_with? "..." %}
      else
        __{{arguments[-1][0..-4].id}} << ARGV.first
      {% else %}
        # Exceptions
      when .includes? '='
          raise Clicr::UnknownVariable.new "{{name.id}}: {{unknown_variable.id}}: '#{ARGV.first.split('=')[0]}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
      else
          raise Clicr::UnknownCommand.new "{{name.id}}: {{unknown_command.id}}: '#{ARGV.first}'\n'{{name.id}} --{{help_option.id}}' {{help.id}}"
      {% end %}
      end
      ARGV.shift?
    end

    # At the end execute the command {{name}}
    {% if action %}
      return {{action.split("()")[0].id}}({% if variables.is_a? NamedTupleLiteral %}\
         {% for var, _x in variables %}
         {{var.id}}: __{{var.id}},{% end %}{% end %}\
      {% if options.is_a? NamedTupleLiteral %}
         {% for opt, _x in options %}{{opt.id}}: __{{opt.id}},
      {% end %}{% end %}\
      {% if arguments.is_a? ArrayLiteral %}\
        {% for arg in arguments %}\
          {% if arg.ends_with? "..." %}\
            {{arg[0..-4].id}}: __{{arg[0..-4].id}},
          {% else %}\
            {{arg.id}}: __{{arg.id}},
        {% end %}\
      {% end %}{% end %}){% if action.includes? "()" %}{{action.split("()")[1].id}}{% end %}
    {% else %}
      help.call
    {% end %}
  end

  def self.align(io, help_block : Tuple)
    max_size = help_block.max_of { |arg, _| arg.size }
    help_block.each do |arg, help|
      io << "\n  " << arg
      (max_size - arg.size).times do
        io << ' '
      end
      io << "   " << help
    end
  end
end

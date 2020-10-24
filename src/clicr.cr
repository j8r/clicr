require "./command"

class Clicr
  @sub : Subcommand

  property help_callback : Proc(String, Nil) = ->(msg : String) do
    STDOUT.puts msg
    exit 0
  end

  property error_callback : Proc(String, Nil) = ->(msg : String) do
    STDERR.puts msg
    exit 1
  end

  property help_footer : Proc(String, String) = ->(command : String) do
    "\n'#{command} --help' to show the help."
  end

  property argument_required : Proc(String, String, String) = ->(command : String, argument : String) do
    "argument required for '#{command}': #{argument}"
  end

  property unknown_argument : Proc(String, String, String) = ->(command : String, argument : String) do
    "unknown argument for '#{command}': #{argument}"
  end

  property unknown_command : Proc(String, String, String) = ->(command : String, sub_command : String) do
    "unknown command for '#{command}': '#{sub_command}'"
  end

  property unknown_option : Proc(String, String, String) = ->(command : String, option : String) do
    "unknown option for '#{command}': #{option}"
  end

  getter help_option : String

  protected getter args : Array(String)

  # CLI arguments
  protected getter arguments = Array(String).new

  def initialize(
    *,
    @name : String = Path[PROGRAM_NAME].basename,
    info : String? = nil,
    description : String? = nil,
    @usage_name : String = "Usage: ",
    @commands_name : String = "COMMANDS",
    @options_name : String = "OPTIONS",
    @help_option : String = "help",
    args : Array(String) = ARGV,
    action = nil,
    arguments = nil,
    commands = nil,
    options = nil
  )
    @sub = Command.create(
      info: info,
      description: description,
      action: action,
      arguments: arguments,
      commands: commands,
      options: options,
    )
    @args = args.dup
  end

  def run(@args : Array(String) = @args)
    @sub.exec @name, self
  end

  protected def parse_options(command_name : String, command : Command, & : String | Char, String? ->)
    while arg = @args.shift?
      if string_option = arg.lchop? "--"
        if @help_option == string_option
          return help command_name, command
        else
          var, equal_sign, val = string_option.partition '='
          if equal_sign.empty?
            yield var, nil
          else
            yield var, val
          end
        end
      elsif option = arg.lchop? '-'
        if @help_option[0] === option[0]
          return help command_name, command
        else
          option.each_char do |char_opt|
            yield char_opt, nil
          end
        end
      elsif cmd_arguments = command.arguments
        if !cmd_arguments.is_a?(Array) && @arguments.size + 1 > cmd_arguments.size
          return @error_callback.call(
            @unknown_argument.call(command_name, arg) + @help_footer.call(command_name)
          )
        end
        @arguments << arg
      else
        next if arg.empty?
        command.each_sub_command do |name, short, sub_command|
          if name == arg || arg == short
            return {command_name + ' ' + arg, sub_command}
          end
        end

        return @error_callback.call(
          @unknown_command.call(command_name, arg) + @help_footer.call(command_name)
        )
      end
    end

    if (cmd_arguments = command.arguments) && cmd_arguments.is_a?(Tuple) && cmd_arguments.size > @arguments.size
      @error_callback.call(
        @argument_required.call(command_name, cmd_arguments[-1]) + @help_footer.call(command_name)
      )
    else
      self
    end
  end

  protected def help(command_name : String, command : Command, reason : String? = nil) : Nil
    @help_callback.call(String.build do |io|
      io << @usage_name << command_name << ' '
      command.arguments.try &.each do |arg|
        io << arg << ' '
      end
      if command.sub_commands
        io << @commands_name << ' '
      end
      io << '[' << @options_name << "]\n"
      if description = command.description || command.info
        io << '\n' << description << '\n'
      end
      if command.sub_commands
        io << '\n' << @commands_name
        array = Array({String, String?}).new
        command.each_sub_command do |name, short, sub_command|
          if !short.empty?
            name += ", " + short
          end
          array << {name, (sub_command.info || sub_command.description)}
        end
        align io, array
        io.puts
      end

      if command.options
        io << '\n' << @options_name
        array = Array({String, String?}).new
        command.each_option do |name, option|
          next if name.is_a? Char
          key = "--" + name
          if short = option.short
            key += ", -" + short
          end
          if option.string_option?
            if default = option.default
              key += ' ' + default
            else
              key += " String"
            end
          end
          array << {key, option.info}
        end
        align io, array
        io.puts
      end

      io << @help_footer.call command_name
    end
    )
  end

  private def align(io, array : Array({String, String?})) : Nil
    max_size = array.max_of { |arg, _| arg.size }
    array.sort_by! { |k, v| k }
    array.each do |name, help|
      io << "\n  " << name
      if help
        (max_size - name.to_s.size).times do
          io << ' '
        end
        io << "   " << help
      end
    end
  end
end

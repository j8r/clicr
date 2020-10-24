require "spec"
require "../src/clicr.cr"

class TestCLI
  getter help : String = ""
  getter error : String = ""
  @clicr : Clicr

  def initialize(args)
    other_options = {
      subvar: {
        info:    "sub variable",
        default: nil,
      },
    }

    main_options = {
      name: {
        info:    "Your name",
        default: "foo",
        short:   'n',
      },
      yes: {
        short: 'y',
        info:  "Print the name",
      },
    }

    @clicr = Clicr.new(
      args: args,
      name: "myapp",
      commands: {
        talk: {
          info:    "Talk",
          action:  {"TestCLI.talk": "t"},
          options: main_options,
        },
        "test-multiple-no-limit": {
          action:    {"TestCLI.args": ""},
          arguments: %w(app numbers),
          options:   {
            var: {
              default: nil,
            },
          }.merge(main_options),
        },
        "test-simple": {
          action:    {"TestCLI.args": ""},
          arguments: %w(application folder),
          options:   {name: main_options[:name]},
        },
        "tuple-args": {
          action:    {"TestCLI.tuple_args": ""},
          info:      "Test args",
          arguments: {"one", "two"},
        },
        "test-parens": {
          action: {"TestCLI.args().to_s": ""},
        },
        options_variables: {
          info:        "Test sub options/variables",
          description: <<-E.to_s,
        Multi-line
        description
        E
          action:  {"TestCLI.args": ""},
          options: {
            sub_opt: {
              short: 's',
              info:  "sub options",
            },
          }.merge(**other_options, **main_options),
        },
      },
      options: main_options,
    )
    @clicr.help_callback = ->(msg : String) {
      @help = msg
      # puts msg
    }

    @clicr.error_callback = ->(msg : String) {
      @error = msg
      # puts msg
    }
  end

  def run
    @clicr.run
  end

  def self.tuple_args(arguments : Tuple(String, String))
    arguments
  end

  def self.talk(name : String, yes : Bool)
    {name, yes}
  end

  def self.args(**args)
    args
  end
end

describe Clicr do
  describe "commands" do
    it "runs a full command" do
      TestCLI.new(["talk"]).run.should eq({"foo", false})
    end

    it "runs a single character command" do
      TestCLI.new(["t"]).run.should eq({"foo", false})
    end

    it "tests calling a method with parenthesis" do
      TestCLI.new(["test-parens"]).run.should eq "{}"
    end
  end

  describe "arguments" do
    it "uses simple" do
      TestCLI.new(["test-simple", "myapp", "/tmp"]).run.should eq({
        arguments: ["myapp", "/tmp"],
        name:      "foo",
      })
    end

    it "uses multiple with no limit" do
      TestCLI.new(["test-multiple-no-limit", "myapp", "-y", "2", "3"]).run.should eq({
        arguments: ["myapp", "2", "3"],
        var:       nil,
        name:      "foo",
        yes:       true,
      })
    end

    it "sets a variable with arguments" do
      TestCLI.new(["test-multiple-no-limit", "myapp", "2", "--var", "Value", "3"]).run.should eq({
        arguments: ["myapp", "2", "3"],
        var:       "Value",
        name:      "foo",
        yes:       false,
      })
    end

    describe "tuple args" do
      it "provides the expected number" do
        TestCLI.new(["tuple-args", "1", "2"]).run.should eq({"1", "2"})
      end

      it "fails because of too many" do
        cli = TestCLI.new(["tuple-args", "1"])
        cli.run.should be_nil
        cli.error.should_not be_empty
      end

      it "fails because of too few" do
        cli = TestCLI.new(["tuple-args", "1", "2", "3"])
        cli.run.should be_nil
        cli.error.should_not be_empty
      end
    end
  end

  describe "unknown command" do
    it "not known sub-command" do
      cli = TestCLI.new(["talk", "Not exists"])
      cli.run.should be_nil
      cli.error.should_not be_empty
    end
  end

  describe "options" do
    describe "boolean" do
      it "use one at the end" do
        TestCLI.new(["talk", "--yes"]).run.should eq({"foo", true})
      end

      it "uses a single char one at the end" do
        TestCLI.new(["talk", "-y"]).run.should eq({"foo", true})
      end

      it "uses concatenated single chars" do
        TestCLI.new(["options_variables", "-ys"]).run.should eq({
          subvar:  nil,
          sub_opt: true,
          name:    "foo",
          yes:     true,
        })
      end
    end

    describe "string" do
      it "sets one with equal '='" do
        TestCLI.new(["talk", "--name=bar"]).run.should eq({"bar", false})
      end

      it "sets one with space ' '" do
        TestCLI.new(["talk", "--name", "bar"]).run.should eq({"bar", false})
      end

      it "sets a short one" do
        TestCLI.new(["talk", "-n", "bar"]).run.should eq({"bar", false})
      end
    end
  end

  describe "help" do
    describe "print main help" do
      help = <<-HELP
      Usage: myapp COMMANDS [OPTIONS]

      COMMANDS
        options_variables        Test sub options/variables
        talk, t                  Talk
        test-multiple-no-limit
        test-parens
        test-simple
        tuple-args               Test args

      OPTIONS
        --name, -n foo   Your name
        --yes, -y        Print the name

      'myapp --help' to show the help.
      HELP
      it "with -h" do
        cli = TestCLI.new(["-h"])
        cli.run
        cli.help.should eq help
      end

      it "with no arguments" do
        cli = TestCLI.new Array(String).new
        cli.run
        cli.help.should eq help
      end
    end

    it "prints for sub command" do
      cli = TestCLI.new(["options_variables", "--help"])
      cli.run
      cli.help.should eq <<-HELP
      Usage: myapp options_variables [OPTIONS]

      Multi-line
      description

      OPTIONS
        --name, -n foo    Your name
        --sub_opt, -s     sub options
        --subvar String   sub variable
        --yes, -y         Print the name

      'myapp options_variables --help' to show the help.
      HELP
    end
  end
end

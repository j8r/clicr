require "./spec_helper"

struct SimpleCli
  getter result : String = ""

  def initialize
    Clicr.create(
      commands: {
        talk: {
          alias:  't',
          info:   "Talk",
          action: "test",
        },
        run: {
          info:      "Tests vars",
          action:    "run",
          arguments: %w(application folder),
        },
        test_array: {
          info:      "Tests arrays",
          action:    "array",
          arguments: %w(app numbers...),
          variables: {
            var: {
              default: nil,
            },
          },
        },
        options_variables: {
          info:      "Test sub options/variables",
          action:    "options_variables",
          variables: {
            subvar: {
              info:    "sub variable",
              default: "SUB",
            },
          },
          options: {
            sub_opt: {
              short: 's',
              info:  "sub options",
            },
          },
        },
        klass: {
          info:      "klass",
          action:    "@result = Klass.new().met",
          variables: {
            var: {
              info:    "an variable passed to the constructor",
              default: "default",
            },
          },
        },
      },
      variables: {
        name: {
          info:    "Your name",
          default: "foo",
        },
      },
      options: {
        yes: {
          short: 'y',
          info:  "Print the name",
        },
      }
    )
  end

  struct Klass
    @var : String

    def initialize(name, @var, yes)
    end

    def met
      @var
    end
  end

  def test(name, yes)
    @result = "#{yes} #{name}"
  end

  def run(name, yes, application, folder)
    @result = application + " runned in " + folder
  end

  def array(name, yes, app, numbers, var)
    @result = "#{yes} #{app} #{numbers.join(' ')} #{var}"
  end

  def options_variables(name, yes, sub_opt, subvar)
    @result = "#{sub_opt} #{subvar}"
  end
end

describe Clicr do
  describe "simple cli" do
    describe "commands" do
      it "run the command" do
        ARGV.replace ["talk"]
        SimpleCli.new.result.should eq "false foo"
      end
      it "run the single character command" do
        ARGV.replace ["t"]
        SimpleCli.new.result.should eq "false foo"
      end
    end

    describe "arguments" do
      it "uses simple" do
        ARGV.replace ["run", "myapp", "/tmp"]
        SimpleCli.new.result.should eq "myapp runned in /tmp"
      end

      it "uses multiple with option" do
        ARGV.replace ["test_array", "myapp", "-y", "2", "3"]
        SimpleCli.new.result.should eq "true myapp 2 3 "
      end

      it "sets a variable at the end" do
        ARGV.replace ["test_array", "myapp", "2", "3", "var=T"]
        SimpleCli.new.result.should eq "false myapp 2 3 T"
      end

      it "sets a variable at the begining" do
        ARGV.replace ["test_array", "myapp", "var=T", "2", "3"]
        SimpleCli.new.result.should eq "false myapp 2 3 T"
      end

      it "sets a variable in the midde" do
        ARGV.replace ["test_array", "myapp", "2", "var=T", "3"]
        SimpleCli.new.result.should eq "false myapp 2 3 T"
      end
    end

    describe "variables" do
      it "set value at the end" do
        ARGV.replace ["talk", "name=bar"]
        SimpleCli.new.result.should eq "false bar"
      end
      it "set value at the beginning" do
        ARGV.replace ["name=bar", "talk"]
        SimpleCli.new.result.should eq "false bar"
      end
    end

    describe "options" do
      it "use one at the end" do
        ARGV.replace ["talk", "--yes"]
        SimpleCli.new.result.should eq "true foo"
      end
      it "uses a single char one at the end" do
        ARGV.replace ["talk", "-y"]
        SimpleCli.new.result.should eq "true foo"
      end

      it "uses concatenated single chars" do
        ARGV.replace ["options_variables", "-ys"]
        SimpleCli.new.result.should eq "true SUB"
      end
    end

    describe "options/variables of sub command" do
      it "by setting no values" do
        ARGV.replace ["options_variables"]
        SimpleCli.new.result.should eq "false SUB"
      end
      it "by setting values" do
        ARGV.replace ["options_variables", "--sub-opt", "subvar=VALUE"]
        SimpleCli.new.result.should eq "true VALUE"
      end
    end

    it "sets all parameters" do
      ARGV.replace ["talk", "-y", "name=bar"]
      SimpleCli.new.result.should eq "true bar"
    end

    it "uses a variable assignation with a class and a method" do
      ARGV.replace ["klass", "var=value"]
      SimpleCli.new.result.should eq "value"
    end
  end
end

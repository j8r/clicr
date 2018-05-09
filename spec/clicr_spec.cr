require "./spec_helper"

struct SimpleCli
  getter result : String = ""

  def initialize
    Clicr.create(
      commands: {
        talk: {
          alias: 't',
          info: "Talk",
          action: "test",
        },
        run: {
          info: "Tests vars",
          action: "run",
          arguments: %w(application folder),
        },
      },
      variables: {
        name: {
          info: "Your name",
          default: "foo",
        },
      },
      options: {
        yes: {
          short: 'y',
          info: "Print the name",
        }
      }
    )
  end

  def test(name, yes)
    @result = (yes ? "yes " : "no ") + name
  end

  def run(name, yes, application, folder)
    @result = application + " runned in " + folder
  end
end

describe Clicr do
  describe "simple cli" do
    describe "commands" do
      it "run the command" do
        ARGV.replace ["talk"]
        SimpleCli.new.result.should eq "no foo"
      end
      it "run the single character command" do
        ARGV.replace ["t"]
        SimpleCli.new.result.should eq "no foo"
      end
    end

    describe "arguments" do
      it "use" do
        ARGV.replace ["run", "myapp", "/tmp"]
        SimpleCli.new.result.should eq "myapp runned in /tmp"
      end
    end

    describe "variables" do
      it "set value at the end" do
        ARGV.replace ["talk", "name=bar"]
        SimpleCli.new.result.should eq "no bar"
      end
      it "set value at the beginning" do
        ARGV.replace ["name=bar", "talk"]
        SimpleCli.new.result.should eq "no bar"
      end
    end

    describe "options" do
      it "set option at the end" do
        ARGV.replace ["talk", "--yes"]
        SimpleCli.new.result.should eq "yes foo"
      end
      it "set single character option at the end" do
        ARGV.replace ["talk", "-y"]
        SimpleCli.new.result.should eq "yes foo"
      end
      it "set option at the beginning" do
        ARGV.replace ["--yes", "talk"]
        SimpleCli.new.result.should eq "yes foo"
      end
      it "set single character option at the beginning" do
        ARGV.replace ["-y", "talk"]
        SimpleCli.new.result.should eq "yes foo"
      end
    end
    it "set all parameters" do
      ARGV.replace ["-y", "name=bar", "talk"]
      SimpleCli.new.result.should eq "yes bar"
    end
  end
end

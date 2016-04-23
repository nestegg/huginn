require 'rails_helper'

describe Huginn::DotHelper do
  describe "with example Agents" do
    class Huginn::Agents::DotFoo < Huginn::Agent
      default_schedule "2pm"

      def check
        create_event :payload => {}
      end
    end

    class Huginn::Agents::DotBar < Huginn::Agent
      cannot_be_scheduled!

      def check
        create_event :payload => {}
      end
    end

    before do
      stub(Huginn::Agents::DotFoo).valid_type?("Huginn::Agents::DotFoo") { true }
      stub(Huginn::Agents::DotBar).valid_type?("Huginn::Agents::DotBar") { true }
    end

    describe "#agents_dot" do
      before do
        @agents = [
          @foo = Huginn::Agents::DotFoo.new(name: "foo").tap { |agent|
            agent.user = users(:bob)
            agent.save!
          },

          @bar1 = Huginn::Agents::DotBar.new(name: "bar1").tap { |agent|
            agent.user = users(:bob)
            agent.sources << @foo
            agent.save!
          },

          @bar2 = Huginn::Agents::DotBar.new(name: "bar2").tap { |agent|
            agent.user = users(:bob)
            agent.sources << @foo
            agent.propagate_immediately = true
            agent.disabled = true
            agent.save!
          },

          @bar3 = Huginn::Agents::DotBar.new(name: "bar3").tap { |agent|
            agent.user = users(:bob)
            agent.sources << @bar2
            agent.save!
          },
        ]
      end

      it "generates a DOT script" do
        expect(agents_dot(@agents)).to match(%r{
          \A
          digraph \x20 "Agent \x20 Event \x20 Flow" \{
            node \[ [^\]]+ \];
            edge \[ [^\]]+ \];
            (?<foo>\w+) \[label=foo\];
            \k<foo> -> (?<bar1>\w+) \[style=dashed\];
            \k<foo> -> (?<bar2>\w+) \[color="\#999999"\];
            \k<bar1> \[label=bar1\];
            \k<bar2> \[label=bar2,style="rounded,dashed",color="\#999999",fontcolor="\#999999"\];
            \k<bar2> -> (?<bar3>\w+) \[style=dashed,color="\#999999"\];
            \k<bar3> \[label=bar3\];
          \}
          \z
        }x)
      end

      it "generates a richer DOT script" do
        expect(agents_dot(@agents, rich: true)).to match(%r{
          \A
          digraph \x20 "Agent \x20 Event \x20 Flow" \{
            node \[ [^\]]+ \];
            edge \[ [^\]]+ \];
            (?<foo>\w+) \[label=foo,tooltip="Dot \x20 Foo",URL="#{Regexp.quote(huginn_agent_path(@foo))}"\];
            \k<foo> -> (?<bar1>\w+) \[style=dashed\];
            \k<foo> -> (?<bar2>\w+) \[color="\#999999"\];
            \k<bar1> \[label=bar1,tooltip="Dot \x20 Bar",URL="#{Regexp.quote(huginn_agent_path(@bar1))}"\];
            \k<bar2> \[label=bar2,tooltip="Dot \x20 Bar",URL="#{Regexp.quote(huginn_agent_path(@bar2))}",style="rounded,dashed",color="\#999999",fontcolor="\#999999"\];
            \k<bar2> -> (?<bar3>\w+) \[style=dashed,color="\#999999"\];
            \k<bar3> \[label=bar3,tooltip="Dot \x20 Bar",URL="#{Regexp.quote(huginn_agent_path(@bar3))}"\];
          \}
          \z
        }x)
      end
    end
  end

  describe "Huginn::DotHelper::DotDrawer" do
    describe "#id" do
      it "properly escapes double quotaion and backslash" do
        expect(Huginn::DotHelper::DotDrawer.draw(foo: "") {
          id('hello\\"')
        }).to eq('"hello\\\\\\""')
      end
    end
  end
end

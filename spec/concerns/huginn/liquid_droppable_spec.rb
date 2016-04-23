require 'rails_helper'

describe Huginn::LiquidDroppable do
  before do
    class Huginn::DroppableTest
      include Huginn::LiquidDroppable

      def initialize(value)
        @value = value
      end

      attr_reader :value

      def to_s
        "[value:#{value}]"
      end
    end

    class Huginn::DroppableTestDrop
      def value
        @object.value
      end
    end
  end

  describe 'test class' do
    it 'should be droppable' do
      five = Huginn::DroppableTest.new(5)
      expect(five.to_liquid.class).to eq(Huginn::DroppableTestDrop)
      expect(Liquid::Template.parse('{{ x.value | plus:3 }}').render('x' => five)).to eq('8')
      expect(Liquid::Template.parse('{{ x }}').render('x' => five)).to eq('[value:5]')
    end
  end
end

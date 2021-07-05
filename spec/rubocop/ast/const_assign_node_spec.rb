# frozen_string_literal: true

RSpec.describe RuboCop::AST::ConstAssignNode do
  subject(:ast) { parse_source(source).ast }

  let(:casgn_node) { ast.each_node.find(&:casgn_type?) }
  # Relying on `casgn_node_test` for common methods
  # Testing only additional behavior

  describe '#assignment' do
    context 'with a simple assignement' do
      let(:source) { '::Foo::Bar::BAZ = 42' }

      it { expect(casgn_node.assignment.source).to eq '42' }
    end

    context 'with a complex assignement' do
      let(:source) { '::Foo::Bar::BAZ ||= 42' }

      it { expect(casgn_node.assignment.source).to eq '42' }
    end

    context 'with a multiple assignement' do
      let(:source) { '::Foo::Bar::BAZ, = 42' }

      it { expect(casgn_node.assignment).to eq nil }
    end
  end
end

# frozen_string_literal: true

RSpec.describe RuboCop::AST::RegexpNode do
  let(:regexp_node) { parse_source(source).ast }

  describe '.new' do
    let(:source) { '/re/' }

    it { expect(regexp_node.is_a?(described_class)).to be(true) }
  end

  describe '#to_regexp' do
    # rubocop:disable Security/Eval
    context 'with an empty regexp' do
      let(:source) { '//' }

      it { expect(regexp_node.to_regexp).to eq(eval(source)) }
    end

    context 'with a regexp without option' do
      let(:source) { '/.+/' }

      it { expect(regexp_node.to_regexp).to eq(eval(source)) }
    end

    context 'with a multi-line regexp without option' do
      let(:source) { "/\n.+\n/" }

      it { expect(regexp_node.to_regexp).to eq(eval(source)) }
    end

    context 'with an empty regexp with option' do
      let(:source) { '//ix' }

      it { expect(regexp_node.to_regexp).to eq(eval(source)) }
    end

    context 'with a regexp with option' do
      let(:source) { '/.+/imx' }

      it { expect(regexp_node.to_regexp).to eq(eval(source)) }
    end

    context 'with a multi-line regexp with option' do
      let(:source) { "/\n.+\n/ix" }

      it { expect(regexp_node.to_regexp).to eq(eval(source)) }
    end
    # rubocop:enable Security/Eval

    context 'with a regexp with an "o" option' do
      let(:source) { '/abc/io' }

      it { expect(regexp_node.to_regexp.inspect).to eq('/abc/i') }
    end
  end

  describe '#regopt' do
    let(:regopt) { regexp_node.regopt }

    context 'with an empty regexp' do
      let(:source) { '//' }

      it { expect(regopt.regopt_type?).to be(true) }
      it { expect(regopt.children.empty?).to be(true) }
    end

    context 'with a regexp without option' do
      let(:source) { '/.+/' }

      it { expect(regopt.regopt_type?).to be(true) }
      it { expect(regopt.children.empty?).to be(true) }
    end

    context 'with a multi-line regexp without option' do
      let(:source) { "/\n.+\n/" }

      it { expect(regopt.regopt_type?).to be(true) }
      it { expect(regopt.children.empty?).to be(true) }
    end

    context 'with an empty regexp with option' do
      let(:source) { '//ix' }

      it { expect(regopt.regopt_type?).to be(true) }
      it { expect(regopt.children).to eq(%i[i x]) }
    end

    context 'with a regexp with option' do
      let(:source) { '/.+/imx' }

      it { expect(regopt.regopt_type?).to be(true) }
      it { expect(regopt.children).to eq(%i[i m x]) }
    end

    context 'with a multi-line regexp with option' do
      let(:source) { "/\n.+\n/imx" }

      it { expect(regopt.regopt_type?).to be(true) }
      it { expect(regopt.children).to eq(%i[i m x]) }
    end
  end

  describe '#content' do
    let(:content) { regexp_node.content }

    context 'with an empty regexp' do
      let(:source) { '//' }

      it { expect(content).to eq('') }
    end

    context 'with a regexp without option' do
      let(:source) { '/.+/' }

      it { expect(content).to eq('.+') }
    end

    context 'with a multi-line regexp without option' do
      let(:source) { "/\n.+\n/" }

      it { expect(content).to eq("\n.+\n") }
    end

    context 'with an empty regexp with option' do
      let(:source) { '//ix' }

      it { expect(content).to eq('') }
    end

    context 'with a regexp with option' do
      let(:source) { '/.+/imx' }

      it { expect(content).to eq('.+') }
    end

    context 'with a multi-line regexp with option' do
      let(:source) { "/\n.+\n/imx" }

      it { expect(content).to eq("\n.+\n") }
    end
  end

  describe '#interpolation?' do
    context 'with direct variable interpoation' do
      let(:source) { '/\n\n#{foo}(abc)+/' }

      it { expect(regexp_node.interpolation?).to eq(true) }
    end

    context 'with regexp quote' do
      let(:source) { '/\n\n#{Regexp.quote(foo)}(abc)+/' }

      it { expect(regexp_node.interpolation?).to eq(true) }
    end

    context 'with no interpolation returns false' do
      let(:source) { '/a{3,6}/' }

      it { expect(regexp_node.interpolation?).to eq(false) }
    end
  end
end

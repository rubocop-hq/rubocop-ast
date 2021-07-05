# frozen_string_literal: true

RSpec.describe RuboCop::AST::Node do
  let(:ast) { RuboCop::AST::ProcessedSource.new(src, ruby_version).ast }
  let(:node) { ast }

  describe '#value_used?' do
    before :all do
      module RuboCop # rubocop:disable Lint/ConstantDefinitionInBlock
        module AST
          # Patch Node
          class Node
            # Let's make our predicate matchers read better
            def used?
              value_used?
            end
          end
        end
      end
    end

    context 'at the top level' do
      let(:src) { 'expr' }

      it 'is false' do
        expect(node).not_to be_used
      end
    end

    context 'within a method call node' do
      let(:src) { 'obj.method(arg1, arg2, arg3)' }

      it 'is always true' do
        expect(node.child_nodes).to all(be_used)
      end
    end

    context 'at the end of a block' do
      let(:src) { 'obj.method { blah; expr }' }

      it 'is always true' do
        expect(node.children.last).to be_used
      end
    end

    context 'within a class definition node' do
      let(:src) { 'class C < Super; def a; 1; end; self; end' }

      it 'is always true' do
        expect(node.child_nodes).to all(be_used)
      end
    end

    context 'within a module definition node' do
      let(:src) { 'module M; def method; end; 1; end' }

      it 'is always true' do
        expect(node.child_nodes).to all(be_used)
      end
    end

    context 'within a singleton class node' do
      let(:src) { 'class << obj; 1; 2; end' }

      it 'is always true' do
        expect(node.child_nodes).to all(be_used)
      end
    end

    context 'within an if...else..end node' do
      context 'nested in a method call' do
        let(:src) { 'obj.method(if a then b else c end)' }

        it 'is always true' do
          if_node = node.children[2]
          expect(if_node.child_nodes).to all(be_used)
        end
      end

      context 'at the top level' do
        let(:src) { 'if a then b else c end' }

        it 'is true only for the condition' do
          expect(node.condition).to be_used
          expect(node.if_branch).not_to be_used
          expect(node.else_branch).not_to be_used
        end
      end
    end

    context 'within an array literal' do
      context 'assigned to an ivar' do
        let(:src) { '@var = [a, b, c]' }

        it 'is always true' do
          ary_node = node.children[1]
          expect(ary_node.child_nodes).to all(be_used)
        end
      end

      context 'at the top level' do
        let(:src) { '[a, b, c]' }

        it 'is always false' do
          expect(node.child_nodes.map(&:used?)).to all(be false)
        end
      end
    end

    context 'within a while node' do
      let(:src) { 'while a; b; end' }

      it 'is true only for the condition' do
        expect(node.condition).to be_used
        expect(node.body).not_to be_used
      end
    end
  end

  describe '#recursive_basic_literal?' do
    shared_examples 'literal' do |source|
      let(:src) { source }

      it "returns true for `#{source}`" do
        expect(node).to be_recursive_literal
      end
    end

    it_behaves_like 'literal', '!true'
    it_behaves_like 'literal', '"#{2}"'
    it_behaves_like 'literal', '(1)'
    it_behaves_like 'literal', '(false && true)'
    it_behaves_like 'literal', '(false <=> true)'
    it_behaves_like 'literal', '(false or true)'
    it_behaves_like 'literal', '[1, 2, 3]'
    it_behaves_like 'literal', '{ :a => 1, :b => 2 }'
    it_behaves_like 'literal', '{ a: 1, b: 2 }'
    it_behaves_like 'literal', '/./'
    it_behaves_like 'literal', '%r{abx}ixo'
    it_behaves_like 'literal', '1.0'
    it_behaves_like 'literal', '1'
    it_behaves_like 'literal', 'false'
    it_behaves_like 'literal', 'nil'
    it_behaves_like 'literal', "'str'"

    shared_examples 'non literal' do |source|
      let(:src) { source }

      it "returns false for `#{source}`" do
        expect(node).not_to be_recursive_literal
      end
    end

    it_behaves_like 'non literal', '(x && false)'
    it_behaves_like 'non literal', '(x == false)'
    it_behaves_like 'non literal', '(x or false)'
    it_behaves_like 'non literal', '[some_method_call]'
    it_behaves_like 'non literal', '{ :sym => some_method_call }'
    it_behaves_like 'non literal', '{ some_method_call => :sym }'
    it_behaves_like 'non literal', '/.#{some_method_call}/'
    it_behaves_like 'non literal', '%r{abx#{foo}}ixo'
    it_behaves_like 'non literal', 'some_method_call'
    it_behaves_like 'non literal', 'some_method_call(x, y)'
  end

  describe '#pure?' do
    context 'for a method call' do
      let(:src) { 'obj.method(arg1, arg2)' }

      it 'returns false' do
        expect(node).not_to be_pure
      end
    end

    context 'for an integer literal' do
      let(:src) { '100' }

      it 'returns true' do
        expect(node).to be_pure
      end
    end

    context 'for an array literal' do
      context 'with only literal children' do
        let(:src) { '[1..100, false, :symbol, "string", 1.0]' }

        it 'returns true' do
          expect(node).to be_pure
        end
      end

      context 'which contains a method call' do
        let(:src) { '[1, 2, 3, 3 + 4]' }

        it 'returns false' do
          expect(node).not_to be_pure
        end
      end
    end

    context 'for a hash literal' do
      context 'with only literal children' do
        let(:src) { '{range: 1..100, bool: false, str: "string", float: 1.0}' }

        it 'returns true' do
          expect(node).to be_pure
        end
      end

      context 'which contains a method call' do
        let(:src) { '{a: 1, b: 2, c: Kernel.exit}' }

        it 'returns false' do
          expect(node).not_to be_pure
        end
      end
    end

    context 'for a nested if' do
      context 'where the innermost descendants are local vars and literals' do
        let(:src) do
          ['lvar1, lvar2 = method1, method2',
           'if $global',
           '  if @initialized',
           '    [lvar1, lvar2, true]',
           '  else',
           '    :symbol',
           '  end',
           'else',
           '  lvar1',
           'end'].join("\n")
        end

        it 'returns true' do
          if_node = node.children[1]
          expect(if_node.type).to be :if
          expect(if_node).to be_pure
        end
      end

      context 'where one branch contains a method call' do
        let(:src) { 'if $DEBUG then puts "hello" else nil end' }

        it 'returns false' do
          expect(node).not_to be_pure
        end
      end

      context 'where one branch contains an assignment statement' do
        let(:src) { 'if @a then 1 else $global = "str" end' }

        it 'returns false' do
          expect(node).not_to be_pure
        end
      end
    end

    context 'for an ivar assignment' do
      let(:src) { '@var = 1' }

      it 'returns false' do
        expect(node).not_to be_pure
      end
    end

    context 'for a gvar assignment' do
      let(:src) { '$var = 1' }

      it 'returns false' do
        expect(node).not_to be_pure
      end
    end

    context 'for a cvar assignment' do
      let(:src) { '@@var = 1' }

      it 'returns false' do
        expect(node).not_to be_pure
      end
    end

    context 'for an lvar assignment' do
      let(:src) { 'var = 1' }

      it 'returns false' do
        expect(node).not_to be_pure
      end
    end

    context 'for a class definition' do
      let(:src) { 'class C < Super; def method; end end' }

      it 'returns false' do
        expect(node).not_to be_pure
      end
    end

    context 'for a module definition' do
      let(:src) { 'module M; def method; end end' }

      it 'returns false' do
        expect(node).not_to be_pure
      end
    end

    context 'for a regexp' do
      let(:opts) { '' }
      let(:body) { '' }
      let(:src) { "/#{body}/#{opts}" }

      context 'with interpolated segments' do
        let(:body) { '#{x}' }

        it 'returns false' do
          expect(node).not_to be_pure
        end
      end

      context 'with no interpolation' do
        let(:src) { URI::DEFAULT_PARSER.make_regexp.inspect }

        it 'returns true' do
          expect(node).to be_pure
        end
      end

      context 'with options' do
        let(:opts) { 'oix' }

        it 'returns true' do
          expect(node).to be_pure
        end
      end
    end
  end

  describe 'sibling_access' do
    let(:src) { '[0, 1, 2, 3, 4, 5]' }

    it 'returns trivial values for a root node' do
      expect(node.sibling_index).to eq nil
      expect(node.left_sibling).to eq nil
      expect(node.right_sibling).to eq nil
      expect(node.left_siblings).to eq []
      expect(node.right_siblings).to eq []
    end

    context 'for a node with siblings' do
      let(:node) { ast.children[2] }

      it 'returns the expected values' do
        expect(node.sibling_index).to eq 2
        expect(node.left_sibling.value).to eq 1
        expect(node.right_sibling.value).to eq 3
        expect(node.left_siblings.map(&:value)).to eq [0, 1]
        expect(node.right_siblings.map(&:value)).to eq [3, 4, 5]
      end
    end

    context 'for a single child' do
      let(:src) { '[0]' }
      let(:node) { ast.children[0] }

      it 'returns the expected values' do
        expect(node.sibling_index).to eq 0
        expect(node.left_sibling).to eq nil
        expect(node.right_sibling).to eq nil
        expect(node.left_siblings.map(&:value)).to eq []
        expect(node.right_siblings.map(&:value)).to eq []
      end
    end
  end

  describe '#argument_type?' do
    context 'block arguments' do
      let(:src) { 'bar { |a, b = 42, *c, d: 42, **e| nil }' }

      it 'returns true for all argument types' do
        expect(node.arguments.children).to all be_argument_type
        expect(node.arguments).not_to be_argument_type
      end
    end

    context 'method arguments' do
      let(:src) { 'def method_name(a = 0, *b, c: 42, **d); end' }

      it 'returns true for all argument types' do
        expect(node.arguments.children).to all be_argument_type
        expect(node.arguments).not_to be_argument_type
      end
    end
  end

  describe '#class_constructor?' do
    context 'class definition with a block' do
      let(:src) { 'Class.new { a = 42 }' }

      it 'matches' do
        expect(node).to be_class_constructor
      end
    end

    context 'module definition with a block' do
      let(:src) { 'Module.new { a = 42 }' }

      it 'matches' do
        expect(node).to be_class_constructor
      end
    end

    context 'class definition' do
      let(:src) { 'class Foo; a = 42; end' }

      it 'does not match' do
        expect(node.class_constructor?).to eq(nil)
      end
    end

    context 'class definition on outer scope' do
      let(:src) { '::Class.new { a = 42 }' }

      it 'matches' do
        expect(node).to be_class_constructor
      end
    end
  end

  describe '#struct_constructor?' do
    context 'struct definition with a block' do
      let(:src) { 'Struct.new { a = 42 }' }

      it 'matches' do
        expect(node.struct_constructor?).to eq(node.body)
      end
    end

    context 'struct definition without block' do
      let(:src) { 'Struct.new(:foo, :bar)' }

      it 'does not match' do
        expect(node.struct_constructor?).to eq(nil)
      end
    end

    context '::Struct' do
      let(:src) { '::Struct.new { a = 42 }' }

      it 'matches' do
        expect(node.struct_constructor?).to eq(node.body)
      end
    end
  end

  describe '#class_definition?' do
    context 'without inheritance' do
      let(:src) { 'class Foo; a = 42; end' }

      it 'matches' do
        expect(node.class_definition?).to eq(node.body)
      end
    end

    context 'with inheritance' do
      let(:src) { 'class Foo < Bar; a = 42; end' }

      it 'matches' do
        expect(node.class_definition?).to eq(node.body)
      end
    end

    context 'with ::ClassName' do
      let(:src) { 'class ::Foo < Bar; a = 42; end' }

      it 'matches' do
        expect(node.class_definition?).to eq(node.body)
      end
    end

    context 'with Struct' do
      let(:src) do
        <<~RUBY
          Person = Struct.new(:name, :age) do
            a = 2
            def details; end
          end
        RUBY
      end

      it 'matches' do
        class_node = node.children.last
        expect(class_node.class_definition?).to eq(class_node.body)
      end
    end

    context 'constant defined as Struct without block' do
      let(:src) { 'Person = Struct.new(:name, :age)' }

      it 'does not match' do
        expect(node.class_definition?).to eq(nil)
      end
    end

    context 'with Class.new' do
      let(:src) do
        <<~RUBY
          Person = Class.new do
            a = 2
            def details; end
          end
        RUBY
      end

      it 'matches' do
        class_node = node.children.last
        expect(class_node.class_definition?).to eq(class_node.body)
      end
    end

    context 'namespaced class' do
      let(:src) do
        <<~RUBY
          class Foo::Bar::Baz
            BAZ = 2
            def variables; end
          end
        RUBY
      end

      it 'matches' do
        expect(node.class_definition?).to eq(node.body)
      end
    end

    context 'with self singleton class' do
      let(:src) do
        <<~RUBY
          class << self
            BAZ = 2
            def variables; end
          end
        RUBY
      end

      it 'matches' do
        expect(node.class_definition?).to eq(node.body)
      end
    end

    context 'with object singleton class' do
      let(:src) do
        <<~RUBY
          class << foo
            BAZ = 2
            def variables; end
          end
        RUBY
      end

      it 'matches' do
        expect(node.class_definition?).to eq(node.body)
      end
    end
  end

  describe '#module_definition?' do
    context 'using module keyword' do
      let(:src) { 'module Foo; A = 42; end' }

      it 'matches' do
        expect(node.module_definition?).to eq(node.body)
      end
    end

    context 'with ::ModuleName' do
      let(:src) { 'module ::Foo; A = 42; end' }

      it 'matches' do
        expect(node.module_definition?).to eq(node.body)
      end
    end

    context 'with Module.new' do
      let(:src) do
        <<~RUBY
          Person = Module.new do
            a = 2
            def details; end
          end
        RUBY
      end

      it 'matches' do
        module_node = node.children.last
        expect(module_node.module_definition?).to eq(module_node.body)
      end
    end

    context 'prepend Module.new' do
      let(:src) do
        <<~RUBY
          prepend(Module.new do
            a = 2
            def details; end
          end)
        RUBY
      end

      it 'matches' do
        module_node = node.children.last
        expect(module_node.module_definition?).to eq(module_node.body)
      end
    end

    context 'nested modules' do
      let(:src) do
        <<~RUBY
          module Foo
            module Bar
              BAZ = 2
              def variables; end
            end
          end
        RUBY
      end

      it 'matches' do
        expect(node.module_definition?).to eq(node.body)
      end
    end

    context 'namespaced modules' do
      let(:src) do
        <<~RUBY
          module Foo::Bar::Baz
            BAZ = 2
            def variables; end
          end
        RUBY
      end

      it 'matches' do
        expect(node.module_definition?).to eq(node.body)
      end
    end

    context 'included module definition' do
      let(:src) do
        <<~RUBY
          include(Module.new do
            BAZ = 2
            def variables; end
          end)
        RUBY
      end

      it 'matches' do
        module_node = node.children.last
        expect(module_node.module_definition?).to eq(module_node.body)
      end
    end
  end

  describe '#parent_module_name' do
    context 'when node on top level' do
      let(:src) { 'def config; end' }

      it 'returns "Object"' do
        expect(node.parent_module_name).to eq 'Object'
      end
    end

    context 'when node on module' do
      let(:src) do
        <<~RUBY
          module Foo
            attr_reader :config
          end
        RUBY
      end

      it 'returns parent module name with namespaces' do
        method_defined_node = node.children.last
        expect(method_defined_node.parent_module_name).to eq 'Foo'
      end
    end

    context 'when node on singleton class' do
      let(:src) do
        <<~RUBY
          module Foo
            class << self
              attr_reader :config
            end
          end
        RUBY
      end

      it 'returns parent module name with namespaces' do
        method_defined_node = node.children.last.children.last.children.last
        expect(method_defined_node.parent_module_name).to eq 'Foo::#<Class:Foo>'
      end
    end

    context 'when node on class in singleton class' do
      let(:src) do
        <<~RUBY
          module Foo
            class << self
              class Bar
                attr_reader :config
              end
            end
          end
        RUBY
      end

      it 'returns parent module name with namespaces' do
        method_defined_node = node.children.last.children.last.children.last
        expect(method_defined_node.parent_module_name).to eq 'Foo::#<Class:Foo>::Bar'
      end
    end
  end
end

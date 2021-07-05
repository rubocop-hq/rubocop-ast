# frozen_string_literal: true

module RuboCop
  module AST
    # A node extension for `casgn` nodes.
    # Responds to all methods of `const`
    class ConstAssignNode < Node
      include ConstAccessNode

      # @return [Node, nil] the node associated with the assignment.
      # Returns `nil` if is lhs of multiple assignement.
      # Should probably be extracted for other assignment nodes
      def assignment
        children[2] || (parent.mlhs_type? ? nil : parent.children[1])
      end
    end
  end
end

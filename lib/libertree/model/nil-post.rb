module Libertree
  module Model
    class NilPost
      def id
        -1
      end

      def mark_as_unread_by(_)
        # no-op
      end
    end
  end
end

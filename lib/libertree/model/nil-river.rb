module Libertree
  module Model
    class NilRiver
      def num_unread
        0
      end

      def latest_unread(earlier_than_post: nil)
        NilPost.new
      end
    end
  end
end

module Libertree
  module Model
    class PostRead < Sequel::Model(:posts_read)
      def account
        @_account ||= Account[self.account_id]
      end

      def post
        @_post ||= Post[self.post_id]
      end
    end
  end
end

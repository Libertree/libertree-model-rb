module Libertree
  module Model
    class Member < M4DBI::Model(:members)
      def account
        @account ||= Account[self.account_id]
      end

      def server
        @server ||= Server[self.server_id]
      end
      alias :tree :server

      def name_display
        @name_display ||= ( profile.name_display || self.handle )
      end

      def handle
        if self['username']
          self['username'] + "@#{server.name_display}"
        else
          account.username
        end
      end

      def username
        self['username'] || account.username
      end

      def profile
        Profile[ member_id: self.id ]
      end

      def self.create(*args)
        member = super
        Profile.create( member_id: member.id )
        member
      end

      def posts(n = 8)
        Post.s  "SELECT * FROM posts WHERE member_id = ? ORDER BY id DESC LIMIT #{n.to_i}", self.id
      end

      def comments(n = 10)
        Comment.s  "SELECT * FROM comments WHERE member_id = ? ORDER BY id DESC LIMIT #{n.to_i}", self.id
      end
    end
  end
end

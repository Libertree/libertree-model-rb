module Libertree
  module Model
    class IgnoredMember < Sequel::Model(:ignored_members)
      def account
        Libertree::Model::Account[self.account_id]
      end

      def member
        Libertree::Model::Member[self.member_id]
      end
    end
  end
end

module Libertree
  module Model
    class GroupMember < Sequel::Model(:groups_members)
      def group
        Libertree::Model::Group[self.group_id]
      end

      def member
        Libertree::Model::Member[self.member_id]
      end
    end
  end
end

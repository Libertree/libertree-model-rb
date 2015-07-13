module Libertree
  module Model
    class Group < Sequel::Model(:groups)
      def after_create
        super
        # Add creator of the group to the group
        Libertree::Model::GroupMember.create(group_id: self.id, member_id: self.admin_member_id)
      end

      def add_member(member)
        Libertree::Model::GroupMember.create(group_id: self.id, member_id: member.id)
      end

      def remove_member(member)
        self.group_member(member).delete
      end

      def member?(member)
        self.group_member(member).any?
      end

      def members
        Libertree::Model::GroupMember.where(group_id: self.id).map { |gm| gm.member }
      end

      def posts( opts = {} )
        time = Time.at(
          opts.fetch(:time, Time.now.to_f)
        ).strftime("%Y-%m-%d %H:%M:%S.%6N%z")

        Post.s(
          "SELECT * FROM posts_in_group(?,?,?,?,?,?)",
          self.id,
          opts.fetch(:viewer_account_id),
          time,
          opts[:newer],
          opts[:order_by] == :comment,
          opts.fetch(:limit, 30)
        )
      end

      def group_member(member)
        Libertree::Model::GroupMember.where(group_id: self.id, member_id: member.id)
      end
    end
  end
end

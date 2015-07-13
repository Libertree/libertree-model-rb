module Libertree
  module Model
    class Group < Sequel::Model(:groups)
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
    end
  end
end

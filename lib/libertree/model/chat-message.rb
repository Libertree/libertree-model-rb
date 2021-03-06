module Libertree
  module Model
    class ChatMessage < Sequel::Model(:chat_messages)
      def after_create
        super
        self.distribute
      end

      def distribute
        return  if ! self.recipient.tree
        Libertree::Model::Job.create(
          {
            task: 'request:CHAT',
            params: {
              'chat_message_id' => self.id,
              'server_id'       => self.recipient.tree.id,
            }.to_json,
          }
        )
      end

      def sender
        @sender ||= Member[self.from_member_id]
      end

      def recipient
        @recipient ||= Member[self.to_member_id]
      end

      def partner_for(account)
        if account.member == self.sender
          self.recipient
        elsif account.member == self.recipient
          self.sender
        end
      end

      def self.between(account, member, limit = 32)
        return []  if account.nil? || member.nil?

        s(
          %{
            SELECT * FROM (
              SELECT
                *
              FROM
                chat_messages cm
              WHERE
                from_member_id = ?
                AND to_member_id = ?
                OR
                from_member_id = ?
                AND to_member_id = ?
              ORDER BY
                time_created DESC
              LIMIT #{ [limit.to_i, 0].max }
            ) AS x
            ORDER BY time_created
          },
          account.member.id,
          member.id,
          member.id,
          account.member.id
        )
      end

      def self.mark_seen_between(account, member_id)
        return  if account.nil?

        self.where(
          Sequel.lit(
            "from_member_id = ? AND to_member_id = ?",
            member_id.to_i,
            account.member.id
          )
        ).update(seen: true)
      end
    end
  end
end

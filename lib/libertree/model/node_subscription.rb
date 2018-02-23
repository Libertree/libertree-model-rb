module Libertree
  module Model
    class NodeSubscription < Sequel::Model(:node_subscriptions)
      set_primary_key [:id]

      STATES = [ :none,
                 :pending,
                 :unconfigured,
                 :subscribed ]

      many_to_one :node

      def self.for(jid_or_host)
        return self  unless jid_or_host
        jid_or_host = jid_or_host.to_s
        if jid_or_host.include?('@')
          self.where(jid: jid_or_host)
        else
          host_pattern = jid_or_host.to_s
          escaped_host_pattern = host_pattern.gsub(/[\\%_]/) { |m| "\\#{m}" }  # Lifted from Sequel source code
          self.where(Sequel.like(:jid, "%@#{escaped_host_pattern}"))
        end
      end
    end
  end
end

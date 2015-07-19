module Libertree
  module Model
    class Forest < Sequel::Model(:forests)
      def trees
        Server.s(
          %{
            SELECT
              s.*
            FROM
                forests_servers fs
              , servers s
            WHERE
              fs.forest_id = ?
              AND s.id = fs.server_id
          },
          self.id
        )
      end
      alias :servers :trees

      def add(server)
        DB.dbh[
          %{
            INSERT INTO forests_servers (
              forest_id, server_id
            ) SELECT
              ?, ?
            WHERE NOT EXISTS(
              SELECT 1
              FROM forests_servers fs2
              WHERE
                fs2.forest_id = ?
                AND fs2.server_id = ?
            )
          },
          self.id,
          server.id,
          self.id,
          server.id
        ].get
      end

      def remove(server)
        DB.dbh[ "DELETE FROM forests_servers WHERE forest_id = ? AND server_id = ?", self.id, server.id ].get
      end

      def local?
        ! origin_server_id
      end
      def self.all_local_is_member
        where  local_is_member: true
      end

      def origin
        Server[origin_server_id]
      end

      def local_is_member?
        local_is_member
      end

      # @param [Array(String)] domains
      # @return [Array(Model::Server)] any new Server records that were created
      def set_trees_by_domain(domains)
        DB.dbh[ "DELETE FROM forests_servers WHERE forest_id = ?", self.id ].get
        new_trees = []

        domains.each do |domain|
          tree = Model::Server[domain: domain]
          if tree.nil?
            tree = Model::Server.create(domain: domain)
            new_trees << tree
          end

          self.add tree
        end

        new_trees
      end
    end
  end
end

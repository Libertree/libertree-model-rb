require 'libertree/db'

module Libertree
  class NotificationSweeper
    def initialize(db_conf_path: 'database.yaml', dry_run: false)
      Libertree::DB.load_config db_conf_path
      Libertree::DB.dbh  # connect
      require 'libertree/model'
    end

    def run
      Model::Notification.order(Sequel.desc(:id)).paged_each { |n|
        if n.subject.nil? && ! dry_run
          puts "deleting: #{n.inspect}"
          n.delete
        end
      }
    end
  end
end

Libertree::NotificationSweeper.new(dry_run: ARGV[0]).run

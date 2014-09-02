module Libertree
  module Model
    class River < Sequel::Model(:rivers)
      def account
        @account ||= Account[self.account_id]
      end

      def should_contain?( post )
        ! self.contains?(post) && ! post.hidden_by?(self.account) && self.matches_post?(post)
      end

      def contains?( post )
        Libertree::DB.dbh[ "SELECT river_contains_post(?, ?)", self.id, post.id ].single_value
      end

      def add_post( post )
        Libertree::DB.dbh[ "INSERT INTO river_posts ( river_id, post_id ) VALUES ( ?, ? )", self.id, post.id ].get
      end

      def posts( opts = {} )
        time = Time.at( opts.fetch(:time, Time.now.to_f) ).strftime("%Y-%m-%d %H:%M:%S.%6N%z")
        Post.s(%{SELECT * FROM posts_in_river(?,?,?,?,?,?)},
               self.id,
               self.account.id,
               time,
               opts[:newer],
               opts[:order_by] == :comment,
               opts.fetch(:limit, 30))
      end

      def parsed_query(override_cache=false)
        return @parsed_query  if @parsed_query && ! override_cache

        patterns = {
          'phrase'       => /(?<sign>[+-])?"(?<arg>[^"]+)"/,
          'from'         => /(?<sign>[+-])?:from "(?<arg>.+?)"/,
          'river'        => /(?<sign>[+-])?:river "(?<arg>.+?)"/,
          'contact-list' => /(?<sign>[+-])?:contact-list "(?<arg>.+?)"/,
          'via'          => /(?<sign>[+-])?:via "(?<arg>.+?)"/,
          'visibility'   => /(?<sign>[+-])?:visibility (?<arg>[a-z-]+)/,
          'word-count'   => /(?<sign>[+-])?:word-count ?(?<arg>(?<comp>[<>]) ?(?<num>[0-9]+))/,
          'spring'       => /(?<sign>[+-])?:spring (?<arg>"(?<spring_name>.+?)" "(?<handle>.+?)")/,
          'flag'         => /(?<sign>[+-])?:(?<arg>forest|tree|unread|liked|commented|subscribed)/,
          'tag'          => /(?<sign>[+-])?#(?<arg>\S+)/,
          'word'         => /(?<sign>[+-])?(?<arg>\S+)/,
        }

        res = Hash.new
        res.default_proc = proc do |hash,key|
          hash[key] = {
            :negations    => [],
            :requirements => [],
            :regular      => []
          }
        end

        full_query = self.query
        if ! self.appended_to_all
          full_query += ' ' + self.account.rivers_appended.map(&:query).join(' ')
          full_query.strip!
        end

        scanner = StringScanner.new(full_query)
        until scanner.eos? do
          scanner.skip(/\s+/)
          patterns.each_pair do |key, pattern|
            if term = scanner.scan(pattern)
              match = term.match(pattern)
              group = case match[:sign]
                      when '+'
                        :requirements
                      when '-'
                        :negations
                      else
                        :regular
                      end

              case key
              when
                'phrase',
                'via',
                'visibility',
                'word-count',
                'flag',
                'tag'
                res[key][group] << match[:arg]
              when 'from'
                # TODO: eventually remove with_display_name check
                if member = (Member.with_handle(match[:arg]) || Member.with_display_name(match[:arg]))
                  res[key][group] << member.id
                end
              when 'river'
                if river = River[label: match[:arg]]
                  res[key][group] << river  if river.id != self.id
                end
              when 'contact-list'
                if list = ContactList[ account_id: self.account.id, name: match[:arg] ]
                  ids = list.member_ids
                  res[key][group] << ids  unless ids.empty?
                end
              when 'spring'
                # TODO: eventually remove with_display_name check
                if member = (Member.with_handle(match[:handle]) || Member.with_display_name(match[:handle]))
                  pool = Pool[ member_id: member.id, name: match[:spring_name], sprung: true ]
                  res[key][group] << pool  if pool
                end
              when 'word'
                # Only treat a matched word as a simple word if it consists only of word
                # characters.  This excludes URLs or other terms with special characters.
                if match[:arg] =~ /^[[:word:]]+$/
                  res['word'][group] << match[:arg]
                else
                  res['phrase'][group] << match[:arg]
                end
              end

              # move on to the next term
              next res
            end
          end
        end

        @parsed_query = res
      end

      def term_matches_post?(term, post, data)
        case term
        when 'flag'
          # TODO: most of these are slow
          case data
          when 'forest'
            true  # Every post is a post in the forest.  :forest is sort of a no-op term
          when 'tree'
            post.local?
          when 'unread'
            ! post.read_by?(self.account)
          when 'liked'
            post.liked_by? self.account.member
          when 'commented'
            post.commented_on_by? self.account.member
          when 'subscribed'
            self.account.subscribed_to? post
          end
        when 'contact-list'
          data.include? post.member_id
        when 'from'
          post.member_id == data
        when 'river'
          data.matches_post?(post)
        when 'visibility'
          post.visibility == data
        when 'word-count'
          case data
          when /^< ?([0-9]+)$/
            n = $1.to_i
            post.text.scan(/\S+/).count < n
          when /^> ?([0-9]+)$/
            n = $1.to_i
            post.text.scan(/\S+/).count > n
          end
        when 'spring'
          data.includes?(post)
        when 'via'
          post.via == data
        when 'tag'
          post.hashtags.include? data
        when 'phrase', 'word'
          /(?:^|\b|\s)#{Regexp.escape(data)}(?:\b|\s|$)/i === post.text
        end
      end

      def matches_post?(post, ignore_keys=[])
        # Negations: Must not satisfy any of the conditions
        # Requirements: Must satisfy every required condition
        # Regular terms: Must satisfy at least one condition

        conditions = {
          negations:    [],
          requirements: [],
          regular:      []
        }

        query = self.parsed_query
        keys = query.keys - ignore_keys
        keys.each do |term|
          test = lambda {|data| term_matches_post?(term, post, data)}
          query[term].keys.each do |group|
            conditions[group] += query[term][group].map(&test)
          end
        end

        conditions[:negations].none? &&
          conditions[:requirements].all? &&
          (conditions[:regular].count > 0 ? conditions[:regular].any? : true)
      end

      def refresh_posts( n = 512 )
        # TODO: this is slow despite indices.
        #posts = Post.where{|p| ~Sequel.function(:post_hidden_by_account, p.id, account.id)}

        # get posts that are not hidden by account
        posts = Post.not_hidden_by(account)

        flags = self.parsed_query['flag']
        if flags
          flags[:negations].each do |flag|
            case flag
            when 'tree'
              posts = posts.exclude(:remote_id => nil)
            when 'unread'
              posts = Post.read_by(account, posts)
            when 'liked'
              posts = Post.without_liked_by(account.member, posts)
            when 'commented'
              posts = Post.without_commented_on_by(account.member, posts)
            when 'subscribed'
              posts = Post.without_subscribed_to_by(account, posts)
            end
          end

          flags[:requirements].each do |flag|
            case flag
            when 'tree'
              posts = posts.where(:remote_id => nil)
            when 'unread'
              posts = Post.unread_by(account, posts)
            when 'liked'
              posts = Post.liked_by(account.member, posts)
            when 'commented'
              posts = Post.commented_on_by(account.member, posts)
            when 'subscribed'
              posts = Post.subscribed_to_by(account, posts)
            end
          end

          sets = flags[:regular].map do |flag|
            case flag
            when 'tree'
              posts.where(:remote_id => nil)
            when 'unread'
              Post.unread_by(account, posts)
            when 'liked'
              Post.liked_by(account.member, posts)
            when 'commented'
              Post.commented_on_by(account.member, posts)
            when 'subscribed'
              Post.subscribed_to_by(account, posts)
            end
          end.compact

          unless sets.empty?
            posts = sets.reduce do |res, set|
              res.union(set)
            end
          end
        end

        tags = self.parsed_query['tag']
        if tags.values.flatten.count > 0
          # Careful!  Don't trust user input!
          # remove any tag that includes array braces
          excluded = tags[:negations].delete_if    {|t| t =~ /[{}]/ }
          required = tags[:requirements].delete_if {|t| t =~ /[{}]/ }
          regular  = tags[:regular].delete_if      {|t| t =~ /[{}]/ }

          posts = posts.exclude(Sequel.pg_array_op(:hashtags).contains("{#{excluded.join(',')}}"))  unless excluded.empty?
          posts = posts.where  (Sequel.pg_array_op(:hashtags).contains("{#{required.join(',')}}"))  unless required.empty?
          posts = posts.where  (Sequel.pg_array_op(:hashtags).overlaps("{#{regular.join(',')}}" ))  unless regular.empty?
        end

        phrases = self.parsed_query['phrase']
        if phrases.values.flatten.count > 0
          req_patterns = phrases[:requirements].map {|phrase| /(^|\b|\s)#{Regexp.escape(phrase)}(\b|\s|$)/ }
          neg_patterns = phrases[:negations].map    {|phrase| /(^|\b|\s)#{Regexp.escape(phrase)}(\b|\s|$)/ }
          reg_patterns = phrases[:regular].map      {|phrase| /(^|\b|\s)#{Regexp.escape(phrase)}(\b|\s|$)/ }

          unless req_patterns.empty?
            posts = posts.grep(:text, req_patterns, { all_patterns: true, case_insensitive: true })
          end

          unless neg_patterns.empty?
            # NOTE: using Regexp.union results in a postgresql error when the phrase includes '#', or '?'
            pattern = "(#{neg_patterns.map(&:source).join('|')})"
            posts = posts.exclude(Sequel.ilike(:text, pattern))
          end

          unless reg_patterns.empty?
            posts = posts.grep(:text, reg_patterns, { all_patterns: false, case_insensitive: true })
          end
        end

        words = self.parsed_query['word']
        if words.values.flatten.count > 0
          # strip query characters
          words.each_pair {|k,v| words[k].each {|word| word.gsub!(/[\(\)&|!]/, '')}}

          # filter by simple terms first to avoid having to check so many posts
          # TODO: prevent empty arguments to to_tsquery
          posts = posts.where(%{to_tsvector('simple', text)
                               @@ (to_tsquery('simple', ?)
                               && to_tsquery('simple', ?)
                               && to_tsquery('simple', ?))},
                             words[:negations].map{|w| "!#{w}" }.join(' & '),
                             words[:requirements].join(' & '),
                             words[:regular].join(' | '))
        end

        { 'visibility' => :visibility,
          'from'       => :member_id,
          'via'        => :via,
        }.each_pair do |key, column|
          set = self.parsed_query[key]
          if set.values.flatten.count > 0
            excluded = set[:negations]
            required = set[:requirements]
            regular  = set[:regular]

            posts = posts.exclude(column => excluded)  unless excluded.empty?
            posts = posts.where(column => required)    unless required.empty?

            unless regular.empty?
              posts = regular.
                map {|value| posts.where(column => value)}.
                reduce {|res, set| res.union(set)}
            end
          end
        end

        # get up to n posts
        # this is faster than using find_all on the set
        count = 0
        matching = []
        posts.reverse_order(:id).each do |post|
          break  if count >= n

          if res = self.matches_post?(post, ['flag', 'word', 'phrase', 'tag', 'visibility', 'from', 'via'])
            count += 1
            matching << post
          end
        end

        # delete late to minimise interruption
        DB.dbh.transaction do
          DB.dbh[ "DELETE FROM river_posts WHERE river_id = ?", self.id ].get
          if matching.any?
            DB.dbh[ "INSERT INTO river_posts SELECT ?, id FROM posts WHERE id IN ?", self.id, matching.map(&:id)].get
          end
        end
      end

      # @param params Untrusted parameter Hash.  Be careful, this input usually comes from the outside world.
      def revise( params )
        self.label = params['label'].to_s
        self.query = params['query'].to_s

        n = River.num_appended_to_all
        self.appended_to_all = !! params['appended_to_all']
        if River.num_appended_to_all != n || self.appended_to_all
          job_data = {
            task: 'river:refresh-all',
            params: {
              'account_id' => self.account_id,
            }.to_json
          }
          existing_jobs = Job.pending_where(
            %{
              task = ?
              AND params = ?
            },
            job_data[:task],
            job_data[:params]
          )
          if existing_jobs.empty?
            Job.create job_data
          end
        end

        if ! self.appended_to_all
          Libertree::Model::Job.create(
            task: 'river:refresh',
            params: {
              'river_id' => self.id,
            }.to_json
          )
        end
        self.save
      end

      def delete_cascade(force=false)
        if ! force && self.appended_to_all
          Libertree::Model::Job.create(
            task: 'river:refresh-all',
            params: {
              'account_id' => self.account_id,
            }.to_json
          )
        end
        DB.dbh["SELECT delete_cascade_river(?)", self.id].get
      end

      def self.num_appended_to_all
        self.where(:appended_to_all).count
      end

      def self.create(*args)
        n = River.num_appended_to_all
        river = super

        if River.num_appended_to_all != n
          Libertree::Model::Job.create(
            task: 'river:refresh-all',
            params: {
              'account_id' => river.account_id,
            }.to_json
          )
        end

        if ! river.appended_to_all
          Libertree::Model::Job.create(
            task: 'river:refresh',
            params: {
              'river_id' => river.id,
            }.to_json
          )
        end

        river
      end

      def home?
        self.home
      end

      def to_hash
        {
          'id'    => self.id,
          'label' => self.label,
          'query' => self.query,
        }
      end

      def being_processed?
        !! Job[
          task: 'river:refresh',
          params: %|{"river_id":#{self.id}}|,
          time_finished: nil
        ]
      end

      def mark_all_posts_as_read
        DB.dbh[ %{SELECT mark_all_posts_in_river_as_read_by(?,?)},
                self.id,
                self.account.id ].get
      end
    end
  end
end

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
          scanner.skip(/ +/)
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
                  res[key][group] << list
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

      def query_components
        full_query = self.query
        if ! self.appended_to_all
          full_query += ' ' + self.account.rivers_appended.map(&:query).join(' ')
          full_query.strip!
        end

        phrase_pat = /([+-]?"[^"]+")/
        one_text_arg_pat = /([+-]?:(?:from|river|contact-list|via) ".+?")/
        visibility_pat = /([+-]?:visibility [a-z-]+)/
        word_count_pat = /([+-]?:word-count [<>] ?[0-9]+)/
        two_text_args_pat = /([+-]?:(?:spring) ".+?" ".+?")/
        zero_text_args_pat = /([+-]?:(?:forest|tree|unread|liked|commented|subscribed))/
        tag_pat = /([+-]?#\S+)/
        word_pat = /(\S+)/

        pattern = Regexp.union [ phrase_pat,
                                 one_text_arg_pat,
                                 visibility_pat,
                                 word_count_pat,
                                 two_text_args_pat,
                                 zero_text_args_pat,
                                 tag_pat,
                                 word_pat ]

        if ! @query_components
          # Collect static terms on a separate pile to leverage full text search.
          # Static parts are phrases, individual words, or tags
          # - phrases have a space character somewhere; they need to be searched with ILIKE
          # - tags must begin with "#"; they must be searched on the tags field
          # - all others are words; they are searched with tsvector queries
          # At the moment only simple words are treated differently.
          static  = []
          dynamic = []

          full_query.scan(pattern).each { |m|
            # m[0] = match of phrase_pat
            # m[6] = match of tag_pat
            # m[7] = match of word_pat

            # Only treat a matched word as a simple word if it consists only of word
            # characters.  This excludes URLs or other terms with special characters.
            if m[7] =~ /^([+-])?[[:word:]]+$/
              static << m[7]
            else
              dynamic << m[7]
            end

            # the gsub expression takes the phrase out of its quotes
            phrase = m[0].gsub(/^([+-])"/, "\\1").gsub(/^"|"$/, '')  if m[0]
            dynamic << (m[6] || m[5] || m[4] || m[3] || m[2] || m[1] || phrase)
          }
          @query_components = {
            :static  => static.compact,
            :dynamic => dynamic.compact
          }
        end

        @query_components.dup
      end

      def query_parts
        if ! @query_parts
          @query_parts = {
            :static  => {:negations => [], :requirements => [], :regular => []},
            :dynamic => {:negations => [], :requirements => [], :regular => []}
          }

          [:static, :dynamic].each do |group|
            query_components[group].each { |term|
              if term =~ /^-(.+)$/
                @query_parts[group][:negations] << $1
              elsif term =~ /^\+(.+)$/
                @query_parts[group][:requirements] << $1
              else
                @query_parts[group][:regular] << term
              end
            }
          end
        end
        @query_parts.dup
      end

      def term_matches_post?(term, post)
        case term
        when ':forest'
          true  # Every post is a post in the forest.  :forest is sort of a no-op term
        when ':tree'
          post.member.account
        when ':unread'
          ! post.read_by?(self.account)
        when ':liked'
          post.liked_by? self.account.member
        when ':commented'
          post.commented_on_by? self.account.member
        when ':subscribed'
          self.account.subscribed_to? post
        when /^:contact-list "(.+?)"$/
          self.account.has_contact_list_by_name_containing_member?  $1, post.member
        when /^:from "(.+?)"$/
          # TODO: eventually, only match against post.member.handle
          # Need to rewrite existing queries for that.
          if post.local?
            (
              post.member.username == $1 ||
              post.member.name_display == $1
            )
          else
            (
              post.member.handle == $1 ||
              post.member.name_display == $1
            )
          end
        when /^:river "(.+?)"$/
          river = River[label: $1]
          river && river.matches_post?(post)
        when /^:visibility ([a-z-]+)$/
          post.visibility == $1
        when /^:word-count < ?([0-9]+)$/
          n = $1.to_i
          post.text.scan(/\S+/).count < n
        when /^:word-count > ?([0-9]+)$/
          n = $1.to_i
          post.text.scan(/\S+/).count > n
        when /^:spring "(.+?)" "(.+?)"$/
          spring_name, handle = $1, $2
          member = Member.with_handle(handle)
          if member
            pool = Pool[ member_id: member.id, name: spring_name, sprung: true ]
            pool && pool.includes?(post)
          end
        when /^:via "(.+?)"$/
          post.via == $1
        else
          /(?:^|\b|\s)#{Regexp.escape(term)}(?:\b|\s|$)/i === post.text
        end
      end

      def matches_post?(post, perform_static_checks=true)
        # Negations: Must not satisfy any of the conditions
        # Requirements: Must satisfy every required condition
        # Regular terms: Must satisfy at least one condition

        parts = query_parts[:dynamic].dup
        if perform_static_checks
          parts[:negations]    += query_parts[:static][:negations]
          parts[:requirements] += query_parts[:static][:requirements]
          parts[:regular]      += query_parts[:static][:regular]
        end

        test = lambda {|term| term_matches_post?(term, post)}
        parts[:negations].none?(&test) &&
          parts[:requirements].all?(&test) &&
          (parts[:regular].any? ? parts[:regular].any?(&test) : true)
      end

      def refresh_posts( n = 512 )
        # TODO: this is slow despite indices.
        posts = Post.where{|p| ~Sequel.function(:post_hidden_by_account, p.id, account.id)}

        parts = query_parts[:static]
        if parts.values.flatten.count > 0
          # strip query characters
          parts.each_pair {|k,v| parts[k].each {|word| word.gsub!(/[\(\)&|!]/, '')}}

          # filter by simple terms first to avoid having to check so many posts
          posts = posts.where(%{to_tsvector('simple', text)
                               @@ (to_tsquery('simple', ?)
                               && to_tsquery('simple', ?)
                               && to_tsquery('simple', ?))},
                             parts[:negations].map{|w| "!#{w}" }.join(' & '),
                             parts[:requirements].join(' & '),
                             parts[:regular].join(' | '))
        end


        # get up to n posts
        count = 0
        matching = posts.reverse_order(:id).find_all do |post|
          if count >= n
            false
          else
            if res = self.matches_post?(post, false)
              count += 1
            end
            res
          end
        end

        # delete late to minimise interruption
        DB.dbh[ "DELETE FROM river_posts WHERE river_id = ?", self.id ].get
        if matching.any?
          DB.dbh[ "INSERT INTO river_posts SELECT ?, id FROM posts WHERE id IN ?", self.id, matching.map(&:id)].get
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

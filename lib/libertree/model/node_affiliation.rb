module Libertree
  module Model
    class NodeAffiliation < Sequel::Model(:affiliations)
      TYPES = [ :owner,
                :publisher,
                :'publish-only',
                :member,
                :none,
                :outcast ]
    end
  end
end

require 'spec_helper'

describe Libertree::Model::Pool do
  it 'Adding a post to a spring notifies the post author' do
    account_poster = Libertree::Model::Account.create( FactoryGirl.attributes_for(:account) )
    member_poster = account_poster.member

    account_springer = Libertree::Model::Account.create( FactoryGirl.attributes_for(:account) )
    member_springer = account_springer.member

    post = Libertree::Model::Post.create(
      FactoryGirl.attributes_for( :post, member_id: member_poster.id, text: 'post to be sprung' )
    )

    spring = Libertree::Model::Pool.create(
      FactoryGirl.attributes_for( :pool, member_id: member_springer.id, name: 'Post Feed', sprung: true )
    )

    expect(account_poster.notifications.count).to eq 0

    spring << post

    account_poster = Libertree::Model::Account[ account_poster.id ]
    expect(account_poster.notifications.count).to eq 1

    subject = account_poster.notifications[0].subject
    expect(subject).to be_kind_of Libertree::Model::PoolPost
    expect(subject.pool).to eq spring
    expect(subject.post).to eq post
  end

  it 'Adding a post to a pool does not notify the author' do
    account_poster = Libertree::Model::Account.create( FactoryGirl.attributes_for(:account) )
    member_poster = account_poster.member

    account_pooler = Libertree::Model::Account.create( FactoryGirl.attributes_for(:account) )
    member_pooler = account_pooler.member

    post = Libertree::Model::Post.create(
      FactoryGirl.attributes_for( :post, member_id: member_poster.id, text: 'post to be sprung' )
    )

    pool = Libertree::Model::Pool.create(
      FactoryGirl.attributes_for( :pool, member_id: member_pooler.id, name: 'Post Feed', sprung: false )
    )

    expect(account_poster.notifications.count).to eq 0

    pool << post

    account_poster = Libertree::Model::Account[ account_poster.id ]
    expect(account_poster.notifications.count).to eq 0
  end

  describe "#posts" do
    let(:subject) {
      pool.posts(opts)
    }
    let(:opts) { {} }

    context "given a pool with posts" do
      let(:account_poster) { Libertree::Model::Account.create( FactoryGirl.attributes_for(:account) ) }
      let(:member_poster) { account_poster.member }

      let(:account_pooler) { Libertree::Model::Account.create( FactoryGirl.attributes_for(:account) ) }
      let(:member_pooler) { account_pooler.member }

      let!(:post1) { Libertree::Model::Post.create(
        FactoryGirl.attributes_for( :post, member_id: member_poster.id, text: 'post to be sprung', remote_id: nil )
      ) }

      let!(:post2) { Libertree::Model::Post.create(
        FactoryGirl.attributes_for( :post, member_id: member_poster.id, text: 'post to be sprung', remote_id: nil )
      ) }

      let!(:post3) { Libertree::Model::Post.create(
        FactoryGirl.attributes_for( :post, member_id: member_poster.id, text: 'post to be sprung', remote_id: nil )
      ) }

      let(:pool) { Libertree::Model::Pool.create(
        FactoryGirl.attributes_for( :pool, member_id: member_pooler.id, name: 'Post Feed', sprung: false )
      )}

      before do
        pool << post1
        pool << post2
        pool << post3
      end

      it "returns a dataset with the posts in reverse order of creation" do
        expect(subject.to_a.map(&:id)).to eq [post3.id, post2.id, post1.id]
      end

      context "after a post has been updated" do
        before do
          post2.revise 'updated text'
        end

        context "given the option to order_by_updated" do
          let(:opts) { {order_by_updated: true} }

          it "returns a dataset with the posts in reverse order of change" do
            expect(subject.to_a.map(&:id)).to eq [post2.id, post3.id, post1.id]
          end
        end
      end

      context "after a post has been commented on" do
        before do
          Libertree::Model::Comment.create(
            member_id: member_pooler.id,
            post_id: post1.id,
            text: "wow",
          )
        end

        context "given the option to order_by_updated" do
          let(:opts) { {order_by_updated: true} }

          it "returns a dataset with the posts in reverse order of change" do
            expect(subject.to_a.map(&:id)).to eq [post1.id, post3.id, post2.id]
          end
        end
      end
    end
  end
end

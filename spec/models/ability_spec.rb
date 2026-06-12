# frozen_string_literal: true

require "rails_helper"
require "cancan/matchers"

RSpec.describe Ability, type: :model do
  let(:free_user) do
    User.create!(email: "free@example.com", password: "password123", name: "Free", subscription_tier: "free", role: "owner")
  end

  let(:member_user) do
    User.create!(email: "member@example.com", password: "password123", name: "Member", subscription_tier: "starter", role: "member")
  end

  let(:platform_admin) do
    User.create!(email: "admin@example.com", password: "password123", name: "Admin", admin: true, subscription_tier: "enterprise", role: "owner")
  end

  subject(:ability) { Ability.new(user) }

  context "when user is nil" do
    let(:user) { nil }

    it "has no permissions" do
      expect(ability.can?(:read, Link)).to be false
    end
  end

  context "solo user" do
    let(:user) { free_user }
    let(:platform_admin_user) { platform_admin }
    let!(:other_link) { Link.create!(user: platform_admin_user, destination_url: "https://other.com", name: "Other") }

    it "reads own links only" do
      link = Link.create!(user: user, destination_url: "https://example.com", name: "Mine")
      expect(ability).to be_able_to(:show, link)
      expect(ability).not_to be_able_to(:show, other_link)
      expect(ability).not_to be_able_to(:index, Link)
    end

    it "creates links when under limit" do
      expect(ability).to be_able_to(:create, Link)
    end

    it "blocks create at tier limit" do
      Link.create!(user: user, destination_url: "https://example.com", name: "Mine")
      expect(Ability.new(user.reload)).not_to be_able_to(:create, Link)
    end

    it "allows billing for owner" do
      expect(ability).to be_able_to(:create, :checkout)
    end

    it "denies billing for member role" do
      expect(Ability.new(member_user)).not_to be_able_to(:create, :checkout)
    end

    it "denies portal without stripe customer" do
      expect(ability).not_to be_able_to(:create, :portal)
    end

    it "allows portal with stripe customer for owner" do
      user.update!(stripe_customer_id: "cus_123")
      expect(Ability.new(user)).to be_able_to(:create, :portal)
    end
  end

  context "platform admin" do
    let(:user) { platform_admin }
    let!(:link) { Link.create!(user: free_user, destination_url: "https://example.com", name: "Any") }

    it "indexes and destroys any link but not update others" do
      expect(ability).to be_able_to(:index, Link)
      expect(ability).to be_able_to(:destroy, link)
      expect(ability).not_to be_able_to(:update, link)
    end

    it "manages users without create/destroy" do
      expect(ability).to be_able_to(:index, User)
      expect(ability).to be_able_to(:update, free_user)
      expect(ability).not_to be_able_to(:create, User)
      expect(ability).not_to be_able_to(:destroy, free_user)
    end

    it "reads admin symbols" do
      expect(ability).to be_able_to(:read, :admin_dashboard)
      expect(ability).to be_able_to(:read, :admin_health)
      expect(ability).to be_able_to(:read, :admin_teams)
      expect(ability).to be_able_to(:read, :admin_billing)
      expect(ability).to be_able_to(:create, :admin_billing_portal)
      expect(ability).to be_able_to(:create, :admin_billing_cancel)
      expect(ability).to be_able_to(:read, :admin_campaigns)
      expect(ability).to be_able_to(:destroy, :admin_campaigns)
      expect(ability).to be_able_to(:read, :admin_workspaces)
      expect(ability).to be_able_to(:read, :admin_custom_domains)
      expect(ability).to be_able_to(:read, :admin_web_push)
    end

    it "still manages own links as solo user" do
      own = Link.create!(user: user, destination_url: "https://admin.com", name: "Admin link")
      expect(ability).to be_able_to(:create, Link)
      expect(ability).to be_able_to(:update, own)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"
require "cancan/matchers"

RSpec.describe Ability, type: :model do
  def flag!(key, enabled:)
    FeatureFlag.find_by!(key: key).update!(enabled: enabled)
  end

  let(:free_user) do
    User.create!(email: "free@example.com", password: "password123", name: "Free", subscription_tier: "free", role: "owner")
  end

  let(:member_user) do
    User.create!(email: "member@example.com", password: "password123", name: "Member", subscription_tier: "starter", role: "member")
  end

  let(:growth_user) do
    User.create!(email: "growth@example.com", password: "password123", name: "Growth", subscription_tier: "growth", role: "owner")
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

  context "solo user (workspaces off)" do
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

    it "reads analytics" do
      expect(ability).to be_able_to(:read, :analytics)
    end

    it "denies web push when flag is off" do
      flag!("web_push", enabled: false)
      expect(ability).not_to be_able_to(:create, WebPushSubscription)
    end

    it "allows web push when flag is on" do
      flag!("web_push", enabled: true)
      expect(ability).to be_able_to(:create, WebPushSubscription)
    end
  end

  context "campaigns (workspaces off)" do
    let(:user) { free_user }

    before { flag!("campaigns", enabled: true) }

    it "allows owner to manage own campaigns" do
      campaign = user.campaigns.create!(name: "Launch")
      expect(ability).to be_able_to(:read, campaign)
      expect(ability).to be_able_to(:update, campaign)
      expect(ability).to be_able_to(:destroy, campaign)
      expect(ability).to be_able_to(:assign_links, campaign)
    end

    it "denies member campaign management" do
      campaign = member_user.campaigns.create!(name: "Member campaign")
      member_ability = Ability.new(member_user)
      expect(member_ability).not_to be_able_to(:create, Campaign)
      expect(member_ability).not_to be_able_to(:update, campaign)
    end

    it "denies all campaign abilities when flag is off" do
      flag!("campaigns", enabled: false)
      campaign = user.campaigns.create!(name: "Hidden")
      expect(ability).not_to be_able_to(:read, campaign)
    end
  end

  context "workspaces on" do
    let(:user) { free_user }
    let(:workspace) { user.primary_team.workspaces.first }
    let(:member) { member_user }

    before do
      flag!("workspaces", enabled: true)
      TeamMembership.find_or_create_by!(team: user.primary_team, user: member, role: "member")
      workspace.workspace_memberships.find_or_create_by!(user: member)
    end

    it "scopes links to accessible workspaces instead of user_id" do
      own = Link.create!(user: user, destination_url: "https://a.com", name: "A", workspace: workspace)
      foreign = Link.create!(user: platform_admin, destination_url: "https://b.com", name: "B")

      expect(ability).to be_able_to(:show, own)
      expect(ability).not_to be_able_to(:show, foreign)
    end

    it "allows members to read workspace but not create" do
      member_ability = Ability.new(member)
      expect(member_ability).to be_able_to(:read, workspace)
      expect(member_ability).not_to be_able_to(:create, Workspace)
    end

    it "allows owner to create and destroy workspaces on their team" do
      new_workspace = user.primary_team.workspaces.build(name: "Ops")
      expect(ability).to be_able_to(:create, new_workspace)
      expect(ability).to be_able_to(:destroy, workspace)
    end

    it "denies workspace destroy for team admin role" do
      admin = User.create!(email: "teamadmin@example.com", password: "password123", name: "TA", subscription_tier: "starter", role: "admin")
      TeamMembership.find_or_create_by!(team: user.primary_team, user: admin, role: "admin")
      workspace.workspace_memberships.find_or_create_by!(user: admin)
      admin_ability = Ability.new(admin)
      expect(admin_ability).to be_able_to(:update, workspace)
      expect(admin_ability).not_to be_able_to(:destroy, workspace)
    end

    it "allows team read and invitations for owner" do
      expect(ability).to be_able_to(:read, :team)
      invitation = user.primary_team.team_invitations.build(email: "new@example.com", role: "member", invited_by: user)
      expect(ability).to be_able_to(:create, invitation)
    end

    it "allows any authenticated user to accept invitations" do
      expect(ability).to be_able_to(:accept, TeamInvitation)
    end
  end

  context "campaigns with workspaces on" do
    let(:user) { free_user }
    let(:workspace) { user.primary_team.workspaces.first }

    before do
      flag!("workspaces", enabled: true)
      flag!("campaigns", enabled: true)
    end

    it "scopes campaigns to accessible workspaces" do
      campaign = user.campaigns.create!(name: "WS Campaign", workspace: workspace)
      other = platform_admin.campaigns.create!(name: "Other")

      expect(ability).to be_able_to(:read, campaign)
      expect(ability).not_to be_able_to(:read, other)
    end
  end

  context "custom domains" do
    let(:user) { growth_user }

    before { flag!("custom_domains", enabled: true) }

    it "allows growth tier to manage own domains" do
      domain = user.custom_domains.build(domain: "links.example.com")
      expect(ability).to be_able_to(:create, domain)
    end

    it "denies free tier even when flag is on" do
      free_ability = Ability.new(free_user)
      domain = free_user.custom_domains.build(domain: "free.example.com")
      expect(free_ability).not_to be_able_to(:create, domain)
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

    it "reads admin symbols and oversight actions" do
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

  describe Permissions::Rules do
    let(:user) { free_user }

    it "exposes presenter permissions aligned with feature flags" do
      flag!("campaigns", enabled: true)
      flag!("workspaces", enabled: false)
      starter = User.create!(
        email: "starter@example.com",
        password: "password123",
        name: "Starter",
        subscription_tier: "starter",
        role: "owner"
      )

      hash = Permissions::Rules.new(starter).permissions_hash
      expect(hash[:campaigns][:read]).to be true
      expect(hash[:campaigns][:create]).to be true
      expect(hash[:team][:read]).to be false
      expect(hash[:settings][:billing]).to be true
    end

    it "reflects member billing denial in presenter" do
      hash = Permissions::Rules.new(member_user).permissions_hash
      expect(hash[:settings][:billing]).to be false
    end
  end
end

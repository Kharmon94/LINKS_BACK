# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teams API", type: :request do
  def flag!(key, enabled:)
    FeatureFlag.find_by!(key: key).update!(enabled: enabled)
  end

  def join_team!(team, user, role:)
    user.team_memberships.destroy_all
    user.teams.where(personal: true).find_each(&:destroy!)
    membership = team.team_memberships.create!(user: user, role: role)
    team.workspaces.find_each { |workspace| workspace.workspace_memberships.find_or_create_by!(user: user) }
    membership
  end

  let(:owner) do
    User.create!(
      email: "owner@example.com",
      password: "password123",
      name: "Owner",
      role: "owner",
      subscription_tier: "growth"
    )
  end

  let(:team) { owner.primary_team }

  let(:admin) do
    user = User.create!(
      email: "admin@example.com",
      password: "password123",
      name: "Admin",
      role: "member",
      subscription_tier: "growth"
    )
    join_team!(team, user, role: "admin")
    user
  end

  let(:member) do
    user = User.create!(
      email: "member@example.com",
      password: "password123",
      name: "Member",
      role: "member",
      subscription_tier: "growth"
    )
    join_team!(team, user, role: "member")
    user
  end

  before do
    owner
    flag!("workspaces", enabled: true)
  end

  describe "GET /api/v1/team" do
    it "returns members and pending invitations" do
      admin
      invitation = team.team_invitations.create!(
        email: "pending@example.com",
        role: "member",
        invited_by: owner
      )

      get "/api/v1/team", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["members"]).to be_an(Array)
      expect(body["members"].map { |m| m["email"] }).to include(owner.email, admin.email)
      expect(body["invitations"]).to be_an(Array)
      expect(body["invitations"].first).to include(
        "email" => invitation.email,
        "role" => "member"
      )
    end

    it "returns 403 when workspaces feature is disabled" do
      flag!("workspaces", enabled: false)

      get "/api/v1/team", headers: auth_headers(owner)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to include("Workspaces")
    end
  end

  describe "POST /api/v1/team/invitations" do
    it "allows owner to create an invitation" do
      post "/api/v1/team/invitations",
           params: { email: "new@example.com", role: "admin" },
           headers: auth_headers(owner),
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["invitation"]["email"]).to eq("new@example.com")
      expect(response.parsed_body["invitation"]["role"]).to eq("admin")
    end

    it "allows admin to create an invitation" do
      post "/api/v1/team/invitations",
           params: { email: "new@example.com", role: "member" },
           headers: auth_headers(admin),
           as: :json

      expect(response).to have_http_status(:created)
    end

    it "denies members from creating invitations" do
      post "/api/v1/team/invitations",
           params: { email: "new@example.com", role: "member" },
           headers: auth_headers(member),
           as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects invitations for existing team members" do
      post "/api/v1/team/invitations",
           params: { email: member.email, role: "member" },
           headers: auth_headers(owner),
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("already a team member")
    end

    it "rejects duplicate pending invitations" do
      team.team_invitations.create!(
        email: "dup@example.com",
        role: "member",
        invited_by: owner
      )

      post "/api/v1/team/invitations",
           params: { email: "dup@example.com", role: "member" },
           headers: auth_headers(owner),
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("pending invitation")
    end
  end

  describe "GET /api/v1/team_invitations/:token" do
    it "returns a public invitation preview without authentication" do
      invitation = team.team_invitations.create!(
        email: "invitee@example.com",
        role: "member",
        invited_by: owner
      )

      get "/api/v1/team_invitations/#{invitation.token}"

      expect(response).to have_http_status(:ok)
      preview = response.parsed_body["invitation"]
      expect(preview["email"]).to eq("invitee@example.com")
      expect(preview["teamName"]).to eq(team.name)
      expect(preview).to have_key("expired")
    end
  end

  describe "POST /api/v1/team_invitations/:token/accept" do
    let(:invitee) do
      User.create!(
        email: "invitee@example.com",
        password: "password123",
        name: "Invitee",
        role: "member",
        subscription_tier: "growth"
      )
    end

    let(:invitation) do
      team.team_invitations.create!(
        email: invitee.email,
        role: "admin",
        invited_by: owner
      )
    end

    it "adds the invitee to the team and workspaces when email matches" do
      invitee
      invitation

      post "/api/v1/team_invitations/#{invitation.token}/accept",
           headers: auth_headers(invitee),
           as: :json

      expect(response).to have_http_status(:ok)
      membership = team.team_memberships.find_by!(user: invitee)
      expect(membership.role).to eq("admin")
      team.workspaces.find_each do |workspace|
        expect(workspace.workspace_memberships.exists?(user: invitee)).to be(true)
      end
      expect(invitation.reload.accepted_at).to be_present
    end

    it "returns 403 when the signed-in email does not match the invitation" do
      other = User.create!(
        email: "other@example.com",
        password: "password123",
        name: "Other",
        role: "member",
        subscription_tier: "growth"
      )
      invitation

      post "/api/v1/team_invitations/#{invitation.token}/accept",
           headers: auth_headers(other),
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to include("different email")
    end
  end

  describe "PATCH /api/v1/team/members/:member_id" do
    before { member }

    it "allows owner to update a member role" do
      patch "/api/v1/team/members/#{member.id}",
            params: { role: "admin" },
            headers: auth_headers(owner),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["member"]["role"]).to eq("admin")
      expect(team.team_memberships.find_by!(user: member).role).to eq("admin")
    end

    it "denies admin from updating member roles" do
      patch "/api/v1/team/members/#{member.id}",
            params: { role: "admin" },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/team/members/:member_id" do
    before { member }

    it "allows owner to remove a member" do
      delete "/api/v1/team/members/#{member.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:no_content)
      expect(team.team_memberships.exists?(user: member)).to be(false)
    end

    it "allows admin to remove a member" do
      delete "/api/v1/team/members/#{member.id}", headers: auth_headers(admin)

      expect(response).to have_http_status(:no_content)
      expect(team.team_memberships.exists?(user: member)).to be(false)
    end

    it "denies members from removing other members" do
      other = User.create!(
        email: "other-member@example.com",
        password: "password123",
        name: "Other Member",
        role: "member",
        subscription_tier: "growth"
      )
      join_team!(team, other, role: "member")

      delete "/api/v1/team/members/#{other.id}", headers: auth_headers(member)

      expect(response).to have_http_status(:forbidden)
      expect(team.team_memberships.exists?(user: other)).to be(true)
    end
  end
end

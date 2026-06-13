# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workspaces API", type: :request do
  def flag!(key, enabled:)
    FeatureFlag.find_by!(key: key).update!(enabled: enabled)
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
  let(:personal_workspace) { team.workspaces.find_by!(name: "Personal Workspace") }

  before do
    owner
    flag!("workspaces", enabled: true)
  end

  describe "GET /api/v1/workspaces" do
    it "lists accessible workspaces including the default personal workspace" do
      get "/api/v1/workspaces", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      names = response.parsed_body["workspaces"].map { |w| w["name"] }
      expect(names).to include("Personal Workspace")
    end
  end

  describe "POST /api/v1/workspaces" do
    it "creates a workspace with the creator in members" do
      post "/api/v1/workspaces",
           params: { workspace: { name: "Test Workspace", description: "For testing" } },
           headers: auth_headers(owner),
           as: :json

      expect(response).to have_http_status(:created)
      workspace = response.parsed_body["workspace"]
      expect(workspace["name"]).to eq("Test Workspace")
      member_emails = workspace["members"].map { |m| m["email"] }
      expect(member_emails).to include(owner.email)
    end

    it "includes the created workspace in a subsequent index response" do
      post "/api/v1/workspaces",
           params: { workspace: { name: "Test Workspace" } },
           headers: auth_headers(owner),
           as: :json

      expect(response).to have_http_status(:created)
      created_id = response.parsed_body["workspace"]["id"]

      get "/api/v1/workspaces", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["workspaces"].map { |w| w["id"] }
      expect(ids).to include(created_id)
    end
  end

  describe "PATCH /api/v1/account/active_workspace" do
    let!(:new_workspace) do
      team.workspaces.create!(name: "Second Workspace", description: "Another workspace").tap do |ws|
        ws.workspace_memberships.find_or_create_by!(user: owner)
      end
    end

    it "updates the user's active workspace" do
      patch "/api/v1/account/active_workspace",
            params: { workspace_id: new_workspace.id },
            headers: auth_headers(owner),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]["activeWorkspaceId"]).to eq(new_workspace.id.to_s)
      expect(owner.reload.active_workspace_id).to eq(new_workspace.id)
    end
  end

  describe "DELETE /api/v1/workspaces/:id" do
    it "blocks deleting the team's last workspace" do
      team.workspaces.where.not(id: personal_workspace.id).find_each(&:destroy!)

      delete "/api/v1/workspaces/#{personal_workspace.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("last workspace")
      expect(team.workspaces.exists?(id: personal_workspace.id)).to be(true)
    end
  end
end

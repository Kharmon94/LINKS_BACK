# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Campaigns", type: :request do
  let(:user) do
    User.create!(
      email: "campaigns@example.com",
      password: "password123",
      name: "Campaign User",
      subscription_tier: "starter",
      role: "owner"
    )
  end

  let(:other_user) do
    User.create!(
      email: "other-campaigns@example.com",
      password: "password123",
      name: "Other Campaign User",
      subscription_tier: "starter",
      role: "owner"
    )
  end

  before do
    FeatureFlag.find_by(key: "campaigns").update!(enabled: true)
  end

  describe "CRUD" do
    it "lists campaigns" do
      campaign = user.campaigns.create!(name: "Test Campaign", description: "Desc")
      get "/api/v1/campaigns", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["campaigns"].length).to eq(1)
      expect(body["campaigns"].first["name"]).to eq("Test Campaign")
      expect(body["campaigns"].first["id"]).to eq(campaign.id.to_s)
    end

    it "creates a campaign" do
      expect do
        post "/api/v1/campaigns",
             params: { campaign: { name: "New Campaign", description: "A campaign" } },
             headers: auth_headers(user),
             as: :json
      end.to change(Campaign, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "shows campaign with links" do
      campaign = user.campaigns.create!(name: "Show Me")
      link = user.links.create!(destination_url: "https://example.com", name: "L1", campaign: campaign)
      get "/api/v1/campaigns/#{campaign.id}", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body["campaign"]
      expect(body["links"].length).to eq(1)
      expect(body["links"].first["id"]).to eq(link.id.to_s)
    end

    it "shows campaign by public_id and numeric fallback" do
      campaign = user.campaigns.create!(name: "Public ID Campaign")
      get "/api/v1/campaigns/#{campaign.public_id}", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["campaign"]["publicId"]).to eq(campaign.public_id)

      get "/api/v1/campaigns/#{campaign.id}", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["campaign"]["id"]).to eq(campaign.id.to_s)
    end

    it "updates and destroys campaign" do
      campaign = user.campaigns.create!(name: "Old Name")
      patch "/api/v1/campaigns/#{campaign.id}",
            params: { campaign: { name: "New Name" } },
            headers: auth_headers(user),
            as: :json
      expect(response).to have_http_status(:ok)
      expect(campaign.reload.name).to eq("New Name")

      expect do
        delete "/api/v1/campaigns/#{campaign.id}", headers: auth_headers(user)
      end.to change(Campaign, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "resolves campaign by public_id" do
      campaign = user.campaigns.create!(name: "Public ID Campaign")
      get "/api/v1/campaigns/#{campaign.public_id}", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["campaign"]["publicId"]).to eq(campaign.public_id)
    end
  end

  describe "assign_links" do
    it "assigns links to campaign" do
      campaign = user.campaigns.create!(name: "Assign Test")
      link1 = user.links.create!(destination_url: "https://a.com", name: "A")
      link2 = user.links.create!(destination_url: "https://b.com", name: "B")

      post "/api/v1/campaigns/#{campaign.id}/assign_links",
           params: { link_ids: [link1.id, link2.id] },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:ok)
      expect(link1.reload.campaign_id).to eq(campaign.id)
      expect(link2.reload.campaign_id).to eq(campaign.id)
    end
  end

  describe "with workspaces enabled" do
    before do
      FeatureFlag.find_by(key: "workspaces").update!(enabled: true)
    end

    it "creates a campaign scoped to the active workspace" do
      workspace = user.active_workspace

      expect do
        post "/api/v1/campaigns",
             params: { campaign: { name: "Workspace Campaign", description: "Scoped" } },
             headers: auth_headers(user),
             as: :json
      end.to change(Campaign, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(Campaign.last.workspace_id).to eq(workspace.id)
    end

    it "creates a campaign when active workspace is unset but memberships exist" do
      workspace = user.active_workspace
      user.update!(active_workspace: nil)

      expect do
        post "/api/v1/campaigns",
             params: { campaign: { name: "Fallback Workspace Campaign" } },
             headers: auth_headers(user),
             as: :json
      end.to change(Campaign, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(Campaign.last.workspace_id).to eq(workspace.id)
    end
  end

  describe "PATCH /api/v1/campaigns/:id alert preferences" do
    let!(:campaign) { user.campaigns.create!(name: "Alert Campaign") }

    it "updates campaign alert preferences" do
      patch "/api/v1/campaigns/#{campaign.id}",
            params: {
              campaign: {
                push_alerts_enabled: false,
                email_alerts_enabled: false,
                alert_interval_value: 2,
                alert_interval_unit: "months"
              }
            },
            headers: auth_headers(user),
            as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["campaign"]
      expect(body["pushAlertsEnabled"]).to be false
      expect(body["emailAlertsEnabled"]).to be false
      expect(body["alertIntervalValue"]).to eq(2)
      expect(body["alertIntervalUnit"]).to eq("months")
      expect(campaign.reload.push_alerts_enabled).to be false
      expect(campaign.email_alerts_enabled).to be false
      expect(campaign.alert_interval_value).to eq(2)
      expect(campaign.alert_interval_unit).to eq("months")
    end

    it "returns 422 for invalid alert interval unit" do
      patch "/api/v1/campaigns/#{campaign.id}",
            params: { campaign: { alert_interval_unit: "hours" } },
            headers: auth_headers(user),
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates click-based alert interval" do
      patch "/api/v1/campaigns/#{campaign.id}",
            params: {
              campaign: {
                alert_interval_kind: "clicks",
                alert_interval_value: 10
              }
            },
            headers: auth_headers(user),
            as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["campaign"]
      expect(body["alertIntervalKind"]).to eq("clicks")
      expect(body["alertIntervalValue"]).to eq(10)
      expect(campaign.reload.alert_interval_kind).to eq("clicks")
      expect(campaign.alert_interval_value).to eq(10)
    end

    it "returns 422 for invalid alert interval kind" do
      patch "/api/v1/campaigns/#{campaign.id}",
            params: { campaign: { alert_interval_kind: "hours" } },
            headers: auth_headers(user),
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 when another user patches alert preferences" do
      patch "/api/v1/campaigns/#{campaign.id}",
            params: { campaign: { push_alerts_enabled: false } },
            headers: auth_headers(other_user),
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/campaigns/:id alert fields" do
    it "includes push and email alert preferences" do
      campaign = user.campaigns.create!(
        name: "Alert Fields",
        push_alerts_enabled: false,
        email_alerts_enabled: true
      )

      get "/api/v1/campaigns/#{campaign.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["campaign"]
      expect(body["pushAlertsEnabled"]).to be false
      expect(body["emailAlertsEnabled"]).to be true
      expect(body["alertIntervalKind"]).to eq("time")
      expect(body["alertIntervalValue"]).to eq(1)
      expect(body["alertIntervalUnit"]).to eq("weeks")
    end

    it "defaults push on and email off for new campaigns" do
      fresh = user.campaigns.create!(name: "Fresh Campaign")

      get "/api/v1/campaigns/#{fresh.id}", headers: auth_headers(user)

      body = response.parsed_body["campaign"]
      expect(body["pushAlertsEnabled"]).to be true
      expect(body["emailAlertsEnabled"]).to be false
      expect(body["alertIntervalKind"]).to eq("time")
      expect(body["alertIntervalValue"]).to eq(1)
      expect(body["alertIntervalUnit"]).to eq("weeks")
    end
  end

  describe "PATCH /api/v1/campaigns/:id alert preferences" do
    let(:campaign) { user.campaigns.create!(name: "Alert Campaign") }

    it "updates campaign alert preferences" do
      patch "/api/v1/campaigns/#{campaign.id}",
            params: {
              campaign: {
                push_alerts_enabled: false,
                email_alerts_enabled: false,
                alert_interval_value: 2,
                alert_interval_unit: "months"
              }
            },
            headers: auth_headers(user),
            as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["campaign"]
      expect(body["pushAlertsEnabled"]).to be false
      expect(body["emailAlertsEnabled"]).to be false
      expect(body["alertIntervalValue"]).to eq(2)
      expect(body["alertIntervalUnit"]).to eq("months")
      expect(campaign.reload.push_alerts_enabled).to be false
      expect(campaign.email_alerts_enabled).to be false
      expect(campaign.alert_interval_value).to eq(2)
      expect(campaign.alert_interval_unit).to eq("months")
    end

    it "returns 422 for invalid alert interval unit" do
      patch "/api/v1/campaigns/#{campaign.id}",
            params: { campaign: { alert_interval_unit: "hours" } },
            headers: auth_headers(user),
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates click-based alert interval" do
      patch "/api/v1/campaigns/#{campaign.id}",
            params: {
              campaign: {
                alert_interval_kind: "clicks",
                alert_interval_value: 10
              }
            },
            headers: auth_headers(user),
            as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["campaign"]
      expect(body["alertIntervalKind"]).to eq("clicks")
      expect(body["alertIntervalValue"]).to eq(10)
      expect(campaign.reload.alert_interval_kind).to eq("clicks")
      expect(campaign.alert_interval_value).to eq(10)
    end

    it "returns 422 for invalid alert interval kind" do
      patch "/api/v1/campaigns/#{campaign.id}",
            params: { campaign: { alert_interval_kind: "hours" } },
            headers: auth_headers(user),
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 when another user patches alert preferences" do
      patch "/api/v1/campaigns/#{campaign.id}",
            params: { campaign: { push_alerts_enabled: false } },
            headers: auth_headers(other_user),
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/campaigns/:id alert fields" do
    it "includes push and email alert preferences" do
      campaign = user.campaigns.create!(
        name: "Alert GET",
        push_alerts_enabled: false,
        email_alerts_enabled: true
      )

      get "/api/v1/campaigns/#{campaign.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["campaign"]
      expect(body["pushAlertsEnabled"]).to be false
      expect(body["emailAlertsEnabled"]).to be true
      expect(body["alertIntervalKind"]).to eq("time")
      expect(body["alertIntervalValue"]).to eq(1)
      expect(body["alertIntervalUnit"]).to eq("weeks")
    end

    it "defaults push on and email off for new campaigns" do
      campaign = user.campaigns.create!(name: "Fresh Campaign")

      get "/api/v1/campaigns/#{campaign.id}", headers: auth_headers(user)

      body = response.parsed_body["campaign"]
      expect(body["pushAlertsEnabled"]).to be true
      expect(body["emailAlertsEnabled"]).to be false
    end
  end

  describe "limits and flags" do
    it "rejects create when at campaign limit" do
      free_user = User.create!(
        email: "free@example.com",
        password: "password123",
        name: "Free",
        subscription_tier: "free",
        role: "owner"
      )
      post "/api/v1/campaigns",
           params: { campaign: { name: "Nope" } },
           headers: auth_headers(free_user),
           as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "returns forbidden when campaigns flag is off" do
      FeatureFlag.find_by(key: "campaigns").update!(enabled: false)
      get "/api/v1/campaigns", headers: auth_headers(user)
      expect(response).to have_http_status(:forbidden)
    end
  end
end

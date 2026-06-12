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

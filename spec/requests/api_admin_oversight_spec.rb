# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin oversight API", type: :request do
  let(:admin) do
    User.create!(
      email: "admin@example.com",
      password: "password123",
      name: "Admin",
      admin: true,
      role: "owner"
    )
  end

  let(:user) do
    User.create!(
      email: "owner@example.com",
      password: "password123",
      name: "Owner",
      role: "owner"
    )
  end

  let!(:campaign) { Campaign.create!(user: user, name: "Launch Campaign") }
  let!(:workspace) { user.primary_team.workspaces.first }
  let!(:custom_domain) do
    CustomDomain.create!(
      user: user,
      domain: "links.example.com",
      status: "pending",
      verification_token: "token123"
    )
  end
  let!(:push_subscription) do
    WebPushSubscription.create!(
      user: user,
      endpoint: "https://push.example.com/sub/abc123",
      p256dh: "p256dh-key",
      auth: "auth-key"
    )
  end

  before do
    admin
    user
  end

  describe "GET /api/v1/admin/campaigns" do
    it "lists campaigns for platform admin" do
      get "/api/v1/admin/campaigns", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["meta"]).to include("page", "total")
      row = body["campaigns"].find { |c| c["id"] == campaign.id.to_s }
      expect(row).to include(
        "name" => "Launch Campaign",
        "userEmail" => user.email,
        "linksCount" => 0
      )
    end

    it "forbids non-admin" do
      get "/api/v1/admin/campaigns", headers: auth_headers(user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/admin/campaigns/:id" do
    it "destroys a campaign" do
      expect do
        delete "/api/v1/admin/campaigns/#{campaign.id}", headers: auth_headers(admin)
      end.to change(Campaign, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/admin/workspaces" do
    it "lists workspaces for platform admin" do
      get "/api/v1/admin/workspaces", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      row = response.parsed_body["workspaces"].find { |w| w["id"] == workspace.id.to_s }
      expect(row).to include(
        "name" => workspace.name,
        "teamName" => user.primary_team.name
      )
    end

    it "forbids non-admin" do
      get "/api/v1/admin/workspaces", headers: auth_headers(user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/admin/workspaces/:id" do
    it "destroys a workspace" do
      extra = user.primary_team.workspaces.create!(name: "Extra Workspace")
      expect do
        delete "/api/v1/admin/workspaces/#{extra.id}", headers: auth_headers(admin)
      end.to change(Workspace, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/admin/custom_domains" do
    it "lists custom domains for platform admin" do
      get "/api/v1/admin/custom_domains", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      row = response.parsed_body["customDomains"].find { |d| d["id"] == custom_domain.id.to_s }
      expect(row).to include(
        "domain" => "links.example.com",
        "userEmail" => user.email,
        "status" => "pending"
      )
    end

    it "forbids non-admin" do
      get "/api/v1/admin/custom_domains", headers: auth_headers(user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/admin/custom_domains/:id" do
    it "destroys a custom domain" do
      expect do
        delete "/api/v1/admin/custom_domains/#{custom_domain.id}", headers: auth_headers(admin)
      end.to change(CustomDomain, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/admin/web_push_subscriptions" do
    it "lists push subscriptions for platform admin" do
      get "/api/v1/admin/web_push_subscriptions", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      row = response.parsed_body["webPushSubscriptions"].find { |s| s["id"] == push_subscription.id.to_s }
      expect(row).to include(
        "userEmail" => user.email,
        "endpointPreview" => a_string_including("push.example.com")
      )
    end

    it "forbids non-admin" do
      get "/api/v1/admin/web_push_subscriptions", headers: auth_headers(user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/admin/web_push_subscriptions/:id" do
    it "destroys a push subscription" do
      expect do
        delete "/api/v1/admin/web_push_subscriptions/#{push_subscription.id}", headers: auth_headers(admin)
      end.to change(WebPushSubscription, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end

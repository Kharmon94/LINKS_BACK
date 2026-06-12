# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Analytics", type: :request do
  let(:user) do
    User.create!(
      email: "analytics@example.com",
      password: "password123",
      name: "Analytics User",
      subscription_tier: "starter",
      role: "owner"
    )
  end

  let!(:link) { user.links.create!(destination_url: "https://example.com", name: "Tracked") }
  let!(:campaign) { user.campaigns.create!(name: "Analytics Campaign") }

  before do
    FeatureFlag.find_by(key: "campaigns").update!(enabled: true)
    link.update!(campaign: campaign)
    link.click_events.create!(
      clicked_at: 1.day.ago,
      device_type: "Mobile",
      browser: "Chrome",
      referrer: "https://twitter.com"
    )
    link.increment!(:clicks_count)
  end

  it "returns overview analytics" do
    get "/api/v1/analytics/overview", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body["analytics"]
    expect(body["totalClicks"]).to eq(1)
    expect(body["totalLinks"]).to eq(1)
    expect(body["totalCampaigns"]).to eq(1)
    expect(body["topWorkspaces"]).to eq([])
    expect(body["topLinks"]).to be_present
  end

  it "returns link analytics" do
    get "/api/v1/links/#{link.id}/analytics", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body["analytics"]
    expect(body["totalClicks"]).to eq(1)
    expect(body["quickStats"]).to include("last7Days", "allTime")
    expect(body["clicksOverTime"]).to include("7D", "30D")
    expect(body["deviceBreakdown"]).to be_present
  end

  it "returns campaign analytics" do
    get "/api/v1/campaigns/#{campaign.id}/analytics", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body["analytics"]
    expect(body["totalClicks"]).to eq(1)
    expect(body["recentClicks"]).to be_present
  end
end

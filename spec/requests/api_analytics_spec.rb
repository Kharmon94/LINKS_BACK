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
      referrer: "https://twitter.com",
      country: "United States",
      city: "Chicago"
    )
  end

  it "returns overview analytics with charts" do
    get "/api/v1/analytics/overview", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body["analytics"]
    expect(body["totalClicks"]).to eq(1)
    expect(body["totalLinks"]).to eq(1)
    expect(body["totalCampaigns"]).to eq(1)
    expect(body["topWorkspaces"]).to eq([])
    expect(body["topLinks"]).to be_present
    expect(body["clicksOverTime"]).to include("7D", "30D")
    expect(body["deviceBreakdown"]).to be_present
    expect(body["recentClicks"].length).to eq(1)
    expect(body["recentClicks"].first["shortUrl"]).to be_present
  end

  it "returns link analytics with recentClicks and referrerBreakdown" do
    get "/api/v1/links/#{link.id}/analytics", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body["analytics"]
    expect(body["totalClicks"]).to eq(1)
    expect(body["quickStats"]).to include("last7Days", "allTime", "peakDay", "countries")
    expect(body["clicksOverTime"]).to include("7D", "30D")
    expect(body["deviceBreakdown"]).to be_present
    expect(body["recentClicks"]).to be_present
    expect(body["referrerBreakdown"]).to be_present
  end

  it "returns campaign analytics with referrerBreakdown" do
    get "/api/v1/campaigns/#{campaign.id}/analytics", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body["analytics"]
    expect(body["totalClicks"]).to eq(1)
    expect(body["recentClicks"]).to be_present
    expect(body["referrerBreakdown"]).to be_present
  end

  it "returns poolBreakdown for randomizer links" do
    link.update!(
      link_type: "randomizer",
      pool_entries_attributes: [
        { destination_url: "https://example.com/a", weight: 50, position: 0 },
        { destination_url: "https://example.com/b", weight: 50, position: 1 }
      ]
    )
    entry = link.pool_entries.first
    link.click_events.last.update!(pool_entry: entry, destination_url: "https://example.com/a")

    get "/api/v1/links/#{link.id}/analytics", headers: auth_headers(user)
    body = response.parsed_body["analytics"]
    expect(body["poolBreakdown"]).to be_present
    expect(body["poolBreakdown"].first["clicks"]).to eq(1)
  end

  it "scopes analytics to active workspace when workspaces flag is enabled" do
    FeatureFlag.find_by(key: "workspaces").update!(enabled: true)
    workspace = user.primary_team.workspaces.create!(name: "Scoped WS")
    other_workspace = user.primary_team.workspaces.create!(name: "Other WS")
    user.update!(active_workspace_id: workspace.id)

    scoped_link = user.links.create!(
      destination_url: "https://scoped.com",
      name: "Scoped",
      workspace: workspace
    )
    other_link = user.links.create!(
      destination_url: "https://other.com",
      name: "Other",
      workspace: other_workspace
    )
    scoped_link.click_events.create!(clicked_at: Time.current, device_type: "Desktop")
    other_link.click_events.create!(clicked_at: Time.current, device_type: "Desktop")

    get "/api/v1/analytics/overview", headers: auth_headers(user)
    body = response.parsed_body["analytics"]
    expect(body["totalClicks"]).to eq(1)
    expect(body["totalLinks"]).to eq(1)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::Aggregator do
  let(:user) do
    User.create!(
      email: "agg@example.com",
      password: "password123",
      name: "Agg User",
      subscription_tier: "starter",
      role: "owner"
    )
  end

  let!(:link) { user.links.create!(destination_url: "https://example.com", name: "Tracked") }
  let!(:campaign) { user.campaigns.create!(name: "Camp") }

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

  describe "#link_analytics" do
    it "uses click_events count as totalClicks and includes recentClicks and referrerBreakdown" do
      data = described_class.new(link).link_analytics(link)

      expect(data[:totalClicks]).to eq(1)
      expect(data[:recentClicks].size).to eq(1)
      expect(data[:referrerBreakdown]).to be_present
      expect(data[:quickStats][:allTime]).to eq(1)
    end

    it "includes poolBreakdown for randomizer links" do
      link.update!(
        link_type: "randomizer",
        pool_entries_attributes: [
          { destination_url: "https://example.com/a", weight: 50, position: 0 },
          { destination_url: "https://example.com/b", weight: 50, position: 1 }
        ]
      )
      entry = link.pool_entries.first
      link.click_events.last.update!(pool_entry: entry, destination_url: "https://example.com/a")

      data = described_class.new(link.reload).link_analytics(link.reload)

      expect(data[:poolBreakdown]).to be_present
      expect(data[:poolBreakdown].first[:clicks]).to eq(1)
    end
  end

  describe "#campaign_analytics" do
    it "includes referrerBreakdown and event-based totals" do
      data = described_class.new(campaign).campaign_analytics(campaign)

      expect(data[:totalClicks]).to eq(1)
      expect(data[:referrerBreakdown]).to be_present
      expect(data[:recentClicks].size).to eq(1)
    end
  end

  describe "#overview_for" do
    it "returns event-based totals and overview charts" do
      data = described_class.new(user.scoped_links).overview_for(user)

      expect(data[:totalClicks]).to eq(1)
      expect(data[:clicksOverTime]).to include("7D", "30D")
      expect(data[:deviceBreakdown]).to be_present
      expect(data[:topLinks].first[:clicks]).to eq(1)
    end

    it "returns topWorkspaces when workspaces flag is enabled" do
      FeatureFlag.find_by(key: "workspaces").update!(enabled: true)
      workspace = user.primary_team.workspaces.create!(name: "Main")
      user.update!(active_workspace_id: workspace.id)
      link.update!(workspace: workspace)

      data = described_class.new(user.scoped_links).overview_for(user)

      expect(data[:topWorkspaces]).to be_present
      expect(data[:topWorkspaces].first[:name]).to eq("Main")
      expect(data[:topWorkspaces].first[:clicks]).to eq(1)
    end

    it "ranks topLinks by click_events count, not stale clicks_count" do
      popular = user.links.create!(destination_url: "https://popular.com", name: "Popular", clicks_count: 0)
      stale = user.links.create!(destination_url: "https://stale.com", name: "Stale", clicks_count: 100)
      3.times { popular.click_events.create!(clicked_at: Time.current, device_type: "Desktop") }

      data = described_class.new(user.scoped_links).overview_for(user)

      expect(data[:topLinks].first[:shortUrl]).to eq(popular.as_json_for_client[:shortUrl])
      expect(data[:topLinks].first[:clicks]).to eq(3)
      expect(data[:topLinks].map { |row| row[:clicks] }).not_to include(100)
    end
  end
end

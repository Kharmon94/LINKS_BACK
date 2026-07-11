# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Link click milestone enqueue", type: :model do
  let(:user) do
    User.create!(
      email: "click-alerts@example.com",
      password: "password123",
      name: "Click Alerts",
      role: "owner",
      subscription_tier: "growth",
      notification_preferences: {
        "push_link_alerts" => true,
        "email_link_alerts" => true
      }
    )
  end

  let(:metadata) do
    {
      referrer: nil,
      user_agent: "RSpec",
      device_type: "desktop",
      browser: "Chrome",
      os: "Linux",
      country: nil,
      city: nil,
      ip_hash: "abc"
    }
  end

  it "enqueues DeliverMilestoneAlertJob when click threshold is crossed" do
    link = Link.create!(
      user: user,
      destination_url: "https://example.com",
      name: "Threshold",
      short_code: "thr001",
      clicks_count: 0,
      alert_interval_kind: "clicks",
      alert_interval_value: 1,
      push_alerts_enabled: true,
      last_alerted_clicks: 0
    )

    expect do
      link.record_click_from_metadata!(metadata)
    end.to have_enqueued_job(DeliverMilestoneAlertJob).with("Link", link.id)
  end

  it "enqueues campaign job when campaign click threshold is crossed" do
    campaign = Campaign.create!(
      user: user,
      name: "Camp",
      alert_interval_kind: "clicks",
      alert_interval_value: 1,
      push_alerts_enabled: true,
      last_alerted_clicks: 0
    )
    link = Link.create!(
      user: user,
      campaign: campaign,
      destination_url: "https://example.com",
      name: "Child",
      short_code: "chld01",
      clicks_count: 0,
      alert_interval_kind: "time",
      alert_interval_value: 1,
      alert_interval_unit: "weeks"
    )

    expect do
      link.record_click_from_metadata!(metadata)
    end.to have_enqueued_job(DeliverMilestoneAlertJob).with("Campaign", campaign.id)
  end

  it "does not enqueue when below click threshold" do
    link = Link.create!(
      user: user,
      destination_url: "https://example.com",
      name: "Below",
      short_code: "blw001",
      clicks_count: 0,
      alert_interval_kind: "clicks",
      alert_interval_value: 5,
      push_alerts_enabled: true,
      last_alerted_clicks: 0
    )

    expect do
      link.record_click_from_metadata!(metadata)
    end.not_to have_enqueued_job(DeliverMilestoneAlertJob)
  end
end

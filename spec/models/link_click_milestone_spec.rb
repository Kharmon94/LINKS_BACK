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

  it "delivers milestone when click threshold is crossed" do
    link = Link.create!(
      user: user,
      destination_url: "https://example.com",
      name: "Threshold",
      short_code: "thr001",
      clicks_count: 0,
      alert_interval_kind: "clicks",
      alert_interval_value: 1,
      push_alerts_enabled: true,
      email_alerts_enabled: true,
      last_alerted_clicks: 0
    )

    expect(DeliverMilestoneAlertJob).to receive(:perform_now).with("Link", link.id).and_call_original

    expect do
      link.record_click_from_metadata!(metadata)
    end.to have_enqueued_job(ActionMailer::MailDeliveryJob)

    expect(link.reload.last_alerted_clicks).to eq(1)
  end

  it "sends push when a WebPushSubscription exists on click milestone" do
    link = Link.create!(
      user: user,
      destination_url: "https://example.com",
      name: "Push Threshold",
      short_code: "psh001",
      clicks_count: 0,
      alert_interval_kind: "clicks",
      alert_interval_value: 1,
      push_alerts_enabled: true,
      email_alerts_enabled: false,
      last_alerted_clicks: 0
    )
    user.web_push_subscriptions.create!(
      endpoint: "https://push.example/click",
      p256dh: "p256dh",
      auth: "auth"
    )
    allow(WebPushSender).to receive(:send_to!)

    expect(DeliverMilestoneAlertJob).to receive(:perform_now).with("Link", link.id).and_call_original

    link.record_click_from_metadata!(metadata)

    expect(WebPushSender).to have_received(:send_to!)
    expect(link.reload.last_alerted_clicks).to eq(1)
  end

  it "delivers campaign milestone when campaign click threshold is crossed" do
    campaign = Campaign.create!(
      user: user,
      name: "Camp",
      alert_interval_kind: "clicks",
      alert_interval_value: 1,
      push_alerts_enabled: true,
      email_alerts_enabled: true,
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

    expect(DeliverMilestoneAlertJob).to receive(:perform_now).with("Campaign", campaign.id).and_call_original

    expect do
      link.record_click_from_metadata!(metadata)
    end.to have_enqueued_job(ActionMailer::MailDeliveryJob)

    expect(campaign.reload.last_alerted_clicks).to eq(1)
  end

  it "does not deliver when below click threshold" do
    link = Link.create!(
      user: user,
      destination_url: "https://example.com",
      name: "Below",
      short_code: "blw001",
      clicks_count: 0,
      alert_interval_kind: "clicks",
      alert_interval_value: 5,
      push_alerts_enabled: true,
      email_alerts_enabled: true,
      last_alerted_clicks: 0
    )

    expect(DeliverMilestoneAlertJob).not_to receive(:perform_now)

    link.record_click_from_metadata!(metadata)
    expect(link.reload.last_alerted_clicks).to eq(0)
  end
end

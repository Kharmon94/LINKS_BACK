# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Cron link_milestones", type: :request do
  let(:user) do
    User.create!(
      email: "cron-alerts@example.com",
      password: "password123",
      name: "Cron Alerts",
      role: "owner",
      subscription_tier: "growth",
      notification_preferences: {
        "push_link_alerts" => true,
        "email_link_alerts" => true
      }
    )
  end

  around do |example|
    previous = ENV["CRON_SECRET"]
    ENV["CRON_SECRET"] = "test-cron-secret"
    example.run
  ensure
    if previous.nil?
      ENV.delete("CRON_SECRET")
    else
      ENV["CRON_SECRET"] = previous
    end
  end

  def cron_headers
    { "Authorization" => "Bearer test-cron-secret" }
  end

  it "rejects unauthorized requests" do
    post "/api/v1/cron/link_milestones", as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "delivers due time-based entities inline and returns counts" do
    due_link = Link.create!(
      user: user,
      destination_url: "https://example.com",
      name: "Due",
      short_code: "due001",
      alert_interval_kind: "time",
      alert_interval_value: 1,
      alert_interval_unit: "days",
      push_alerts_enabled: true,
      email_alerts_enabled: false,
      last_alerted_at: 2.days.ago,
      created_at: 3.days.ago
    )

    Link.create!(
      user: user,
      destination_url: "https://example.com/fresh",
      name: "Fresh",
      short_code: "frsh01",
      alert_interval_kind: "time",
      alert_interval_value: 1,
      alert_interval_unit: "weeks",
      push_alerts_enabled: true,
      last_alerted_at: Time.current,
      created_at: Time.current
    )

    Campaign.create!(
      user: user,
      name: "Due Campaign",
      alert_interval_kind: "time",
      alert_interval_value: 1,
      alert_interval_unit: "days",
      push_alerts_enabled: true,
      last_alerted_at: 2.days.ago,
      created_at: 3.days.ago
    )

    allow(WebPushSender).to receive(:send_to!)

    expect(DeliverMilestoneAlertJob).to receive(:perform_now).with("Link", due_link.id).and_call_original
    expect(DeliverMilestoneAlertJob).to receive(:perform_now).with("Campaign", kind_of(Integer)).and_call_original

    expect do
      post "/api/v1/cron/link_milestones", headers: cron_headers, as: :json
    end.not_to have_enqueued_job(DeliverMilestoneAlertJob)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["ok"]).to be(true)
    expect(body["checked"]).to eq(3)
    expect(body["enqueued"]).to eq(2)
    expect(due_link.reload.alert_interval_kind).to eq("time")
  end

  it "does not deliver click-based entities from cron" do
    Link.create!(
      user: user,
      destination_url: "https://example.com",
      name: "Clicks",
      short_code: "clk001",
      alert_interval_kind: "clicks",
      alert_interval_value: 1,
      push_alerts_enabled: true,
      clicks_count: 5,
      last_alerted_clicks: 0
    )

    expect(DeliverMilestoneAlertJob).not_to receive(:perform_now)

    expect do
      post "/api/v1/cron/link_milestones", headers: cron_headers, as: :json
    end.not_to have_enqueued_job(DeliverMilestoneAlertJob)

    body = JSON.parse(response.body)
    expect(body["checked"]).to eq(0)
    expect(body["enqueued"]).to eq(0)
  end
end

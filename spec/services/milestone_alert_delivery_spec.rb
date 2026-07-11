# frozen_string_literal: true

require "rails_helper"

RSpec.describe MilestoneAlertDelivery do
  let(:user) do
    User.create!(
      email: "alerts@example.com",
      password: "password123",
      name: "Alerts User",
      role: "owner",
      subscription_tier: "growth",
      notification_preferences: {
        "push_link_alerts" => true,
        "email_link_alerts" => true
      }
    )
  end

  let(:link) do
    Link.create!(
      user: user,
      destination_url: "https://example.com",
      name: "Launch",
      short_code: "alrt01",
      clicks_count: 0,
      push_alerts_enabled: true,
      email_alerts_enabled: true,
      alert_interval_kind: "clicks",
      alert_interval_value: 2,
      last_alerted_clicks: 0
    )
  end

  describe ".due?" do
    it "is due for clicks when threshold is crossed" do
      link.update!(clicks_count: 2)
      expect(described_class.due?(link)).to be(true)
    end

    it "is not due for clicks below threshold" do
      link.update!(clicks_count: 1)
      expect(described_class.due?(link)).to be(false)
    end

    it "is due for time when interval has elapsed" do
      link.update!(
        alert_interval_kind: "time",
        alert_interval_value: 1,
        alert_interval_unit: "days",
        last_alerted_at: 2.days.ago,
        created_at: 3.days.ago
      )
      expect(described_class.due?(link)).to be(true)
    end

    it "is not due for time when interval has not elapsed" do
      link.update!(
        alert_interval_kind: "time",
        alert_interval_value: 1,
        alert_interval_unit: "weeks",
        last_alerted_at: 1.day.ago,
        created_at: 1.day.ago
      )
      expect(described_class.due?(link)).to be(false)
    end
  end

  describe ".call" do
    before do
      allow(WebPushSender).to receive(:send_to!)
      link.update!(clicks_count: 2)
    end

    it "advances last_alerted_clicks when email is queued even with zero push subs" do
      expect(user.web_push_subscriptions).to be_empty

      expect(Rails.logger).to receive(:warn).with(
        a_string_matching(/push eligible but no successful send.*user_id=#{user.id}.*link_id=#{link.id}/)
      )

      expect do
        described_class.call(link)
      end.to have_enqueued_job(ActionMailer::MailDeliveryJob)

      expect(link.reload.last_alerted_clicks).to eq(2)
    end

    it "does not advance baselines when push is eligible but no subscriptions and email is off" do
      link.update!(email_alerts_enabled: false)
      expect(user.web_push_subscriptions).to be_empty

      expect(Rails.logger).to receive(:warn).with(
        a_string_matching(/push eligible but no successful send/)
      )

      described_class.call(link)

      expect(link.reload.last_alerted_clicks).to eq(0)
    end

    it "advances after a successful push send" do
      link.update!(email_alerts_enabled: false)
      user.web_push_subscriptions.create!(
        endpoint: "https://push.example/ok",
        p256dh: "p256dh",
        auth: "auth"
      )
      allow(WebPushSender).to receive(:send_to!)

      expect(Rails.logger).not_to receive(:warn).with(a_string_matching(/push eligible but no successful send/))

      described_class.call(link)

      expect(WebPushSender).to have_received(:send_to!)
      expect(link.reload.last_alerted_clicks).to eq(2)
    end

    it "warns when all push sends fail and email is off" do
      link.update!(email_alerts_enabled: false)
      user.web_push_subscriptions.create!(
        endpoint: "https://push.example/fail",
        p256dh: "p256dh",
        auth: "auth"
      )
      allow(WebPushSender).to receive(:send_to!).and_raise(StandardError, "boom")

      expect(Rails.logger).to receive(:error).with(a_string_matching(/push failed/))
      expect(Rails.logger).to receive(:warn).with(
        a_string_matching(/push eligible but no successful send.*subscriptions=1/)
      )

      described_class.call(link)

      expect(link.reload.last_alerted_clicks).to eq(0)
    end

    it "does not advance baselines when no channel is eligible" do
      link.update!(push_alerts_enabled: false, email_alerts_enabled: false)

      expect do
        described_class.call(link)
      end.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)

      expect(link.reload.last_alerted_clicks).to eq(0)
    end

    it "sends push to subscriptions and cleans up expired ones" do
      sub = user.web_push_subscriptions.create!(
        endpoint: "https://push.example/expired",
        p256dh: "p256dh",
        auth: "auth"
      )
      fake_response = Struct.new(:code, :body).new("410", "")
      allow(WebPushSender).to receive(:send_to!).and_raise(
        Webpush::ExpiredSubscription.new(fake_response, "push.example")
      )

      described_class.call(link)

      expect(WebPushSubscription.exists?(sub.id)).to be(false)
      expect(link.reload.last_alerted_clicks).to eq(2)
    end

    it "gates on user notification preferences" do
      user.update!(notification_preferences: {
        "push_link_alerts" => false,
        "email_link_alerts" => false
      })

      expect do
        described_class.call(link)
      end.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)

      expect(link.reload.last_alerted_clicks).to eq(0)
    end

    it "is idempotent under lock when already advanced" do
      described_class.call(link)
      expect(link.reload.last_alerted_clicks).to eq(2)

      expect do
        described_class.call(link.reload)
      end.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe "campaign clicks" do
    let(:campaign) do
      Campaign.create!(
        user: user,
        name: "Spring",
        push_alerts_enabled: true,
        email_alerts_enabled: true,
        alert_interval_kind: "clicks",
        alert_interval_value: 3,
        last_alerted_clicks: 0
      )
    end

    it "uses total_clicks for due checks and baselines" do
      Link.create!(
        user: user,
        campaign: campaign,
        destination_url: "https://example.com/a",
        name: "A",
        short_code: "campa1",
        clicks_count: 3
      )

      expect(described_class.due?(campaign)).to be(true)

      allow(WebPushSender).to receive(:send_to!)
      described_class.call(campaign)
      expect(campaign.reload.last_alerted_clicks).to eq(3)
    end
  end
end

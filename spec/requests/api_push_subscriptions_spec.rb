# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Push subscriptions", type: :request do
  let(:user) do
    User.create!(
      email: "push@example.com",
      password: "password123",
      name: "Push User",
      subscription_tier: "free",
      role: "owner"
    )
  end

  let(:token) { JwtService.encode(user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{token}" } }

  it "creates subscription" do
    post "/api/v1/push/subscribe",
         params: {
           subscription: {
             endpoint: "https://example.com/endpoint",
             keys: { p256dh: "p256", auth: "auth" }
           }
         },
         headers: auth_headers,
         as: :json
    expect(response).to have_http_status(:created)
    expect(user.web_push_subscriptions.count).to eq(1)
  end

  it "returns 403 when web_push flag is off" do
    FeatureFlag.find_by!(key: "web_push").update!(enabled: false)

    post "/api/v1/push/subscribe",
         params: {
           subscription: {
             endpoint: "https://example.com/endpoint",
             keys: { p256dh: "p256", auth: "auth" }
           }
         },
         headers: auth_headers,
         as: :json

    expect(response).to have_http_status(:forbidden)
    expect(user.web_push_subscriptions.count).to eq(0)
  end

  it "unsubscribes by endpoint" do
    user.web_push_subscriptions.create!(endpoint: "e", p256dh: "p", auth: "a")
    delete "/api/v1/push/unsubscribe",
           params: { endpoint: "e" },
           headers: auth_headers,
           as: :json
    expect(response).to have_http_status(:no_content)
    expect(user.web_push_subscriptions.count).to eq(0)
  end

  describe "POST /api/v1/push/test" do
    it "sends a test notification via WebPushSender" do
      user.web_push_subscriptions.create!(
        endpoint: "https://push.example/test",
        p256dh: "p256",
        auth: "auth"
      )
      allow(WebPushSender).to receive(:send_to!)

      post "/api/v1/push/test", headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["ok"]).to eq(true)
      expect(body["sent"]).to eq(1)
      expect(body["errors"]).to eq([])
      expect(WebPushSender).to have_received(:send_to!).with(
        an_instance_of(WebPushSubscription),
        hash_including(
          title: "Test notification",
          body: "Push is working on this device",
          url: "/"
        )
      )
    end

    it "returns sent: 0 when user has no subscriptions" do
      post "/api/v1/push/test", headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["ok"]).to eq(false)
      expect(body["sent"]).to eq(0)
    end

    it "returns 403 when web_push flag is off" do
      FeatureFlag.find_by!(key: "web_push").update!(enabled: false)

      post "/api/v1/push/test", headers: auth_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end

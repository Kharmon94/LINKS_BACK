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

  it "creates subscription" do
    post "/api/v1/push/subscribe",
         params: {
           subscription: {
             endpoint: "https://example.com/endpoint",
             keys: { p256dh: "p256", auth: "auth" }
           }
         },
         headers: { "Authorization" => "Bearer #{token}" },
         as: :json
    expect(response).to have_http_status(:created)
    expect(user.web_push_subscriptions.count).to eq(1)
  end

  it "unsubscribes by endpoint" do
    user.web_push_subscriptions.create!(endpoint: "e", p256dh: "p", auth: "a")
    delete "/api/v1/push/unsubscribe",
           params: { endpoint: "e" },
           headers: { "Authorization" => "Bearer #{token}" },
           as: :json
    expect(response).to have_http_status(:no_content)
    expect(user.web_push_subscriptions.count).to eq(0)
  end
end


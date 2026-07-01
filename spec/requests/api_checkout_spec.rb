# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Checkout", type: :request do
  let!(:user) do
    User.create!(
      email: "checkout@example.com",
      password: "password123",
      name: "Checkout User",
      subscription_tier: "free",
      role: "owner",
      password_set_at: Time.current
    )
  end

  let!(:pro_plan) do
    Plan.create!(
      name: "Pro",
      tier: "pro",
      stripe_price_id_monthly: "price_pro_monthly",
      stripe_price_id_yearly: "price_pro_yearly",
      active: true
    )
  end

  before do
    allow(StripeMode).to receive(:secret_key).and_return("sk_test")
  end

  describe "POST /api/v1/checkout/create_session" do
    it "rejects unknown price_id" do
      post "/api/v1/checkout/create_session",
           params: { price_id: "price_unknown" },
           headers: auth_headers(user),
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to eq("Invalid price_id")
    end

    it "creates a checkout session for an active plan price" do
      session = double(url: "https://checkout.stripe.com/session/test")
      expect(Stripe::Checkout::Session).to receive(:create)
        .with(
          hash_including(line_items: [{ price: "price_pro_monthly", quantity: 1 }]),
          { api_key: "sk_test" }
        )
        .and_return(session)

      post "/api/v1/checkout/create_session",
           params: { price_id: "price_pro_monthly" },
           headers: auth_headers(user),
           as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["url"]).to eq("https://checkout.stripe.com/session/test")
    end
  end
end

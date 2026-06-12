# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Stripe Webhooks", type: :request do
  let!(:user) do
    User.create!(
      email: "billing@example.com",
      password: "password123",
      name: "Billing User",
      subscription_tier: "free",
      role: "owner",
      password_set_at: Time.current
    )
  end

  let!(:starter_plan) do
    Plan.create!(
      name: "Starter",
      tier: "starter",
      stripe_price_id_monthly: "price_starter_monthly",
      stripe_price_id_yearly: "price_starter_yearly",
      active: true
    )
  end

  let!(:growth_plan) do
    Plan.create!(
      name: "Growth",
      tier: "growth",
      stripe_price_id_monthly: "price_growth_monthly",
      stripe_price_id_yearly: "price_growth_yearly",
      active: true
    )
  end

  before do
    allow(StripeMode).to receive(:webhook_secret).and_return("whsec_test")
    allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
  end

  def post_webhook(event)
    post "/api/v1/webhooks/stripe",
         params: { type: event.type }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "sig" }
  end

  describe "checkout.session.completed" do
    let(:session) do
      double(
        client_reference_id: user.id.to_s,
        customer: "cus_test123",
        subscription: "sub_test123"
      )
    end

    let(:subscription) do
      double(
        customer: "cus_test123",
        items: double(data: [double(price: double(id: "price_growth_monthly"))])
      )
    end

    let(:event) do
      double(id: "evt_checkout_completed", type: "checkout.session.completed", data: double(object: session))
    end

    before do
      allow(StripeMode).to receive(:secret_key).and_return("sk_test")
      allow(Stripe::Subscription).to receive(:retrieve)
        .with("sub_test123", { api_key: "sk_test" })
        .and_return(subscription)
    end

    it "links stripe customer and updates tier from subscription price" do
      post_webhook(event)
      expect(response).to have_http_status(:ok)
      user.reload
      expect(user.stripe_customer_id).to eq("cus_test123")
      expect(user.subscription_tier).to eq("growth")
    end
  end

  describe "customer.subscription.updated" do
    let(:subscription) do
      double(
        customer: "cus_existing",
        items: double(data: [double(price: double(id: "price_starter_monthly"))])
      )
    end

    let(:event) do
      double(id: "evt_subscription_updated", type: "customer.subscription.updated", data: double(object: subscription))
    end

    before do
      user.update!(stripe_customer_id: "cus_existing")
    end

    it "maps starter price to starter tier" do
      post_webhook(event)
      expect(response).to have_http_status(:ok)
      expect(user.reload.subscription_tier).to eq("starter")
    end
  end

  describe "customer.subscription.deleted" do
    let(:subscription) { double(customer: "cus_existing") }
    let(:event) { double(id: "evt_subscription_deleted", type: "customer.subscription.deleted", data: double(object: subscription)) }

    before do
      user.update!(stripe_customer_id: "cus_existing", subscription_tier: "starter")
    end

    it "downgrades user to free" do
      post_webhook(event)
      expect(response).to have_http_status(:ok)
      expect(user.reload.subscription_tier).to eq("free")
    end
  end
end

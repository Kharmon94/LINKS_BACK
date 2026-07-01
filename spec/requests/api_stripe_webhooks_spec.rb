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

  let!(:pro_plan) do
    Plan.create!(
      name: "Pro",
      tier: "pro",
      stripe_price_id_monthly: "price_pro_monthly",
      stripe_price_id_yearly: "price_pro_yearly",
      active: true
    )
  end

  let!(:starter_plan) do
    Plan.create!(
      name: "Starter",
      tier: "starter",
      stripe_price_id_monthly: "price_starter_monthly",
      stripe_price_id_yearly: "price_starter_yearly",
      active: false
    )
  end

  let!(:growth_plan) do
    Plan.create!(
      name: "Growth",
      tier: "growth",
      stripe_price_id_monthly: "price_growth_monthly",
      stripe_price_id_yearly: "price_growth_yearly",
      active: false
    )
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("STRIPE_WEBHOOK_SECRET").and_return("whsec_test")
    allow(ENV).to receive(:[]).with("STRIPE_WEBHOOK_SECRET_LIVE").and_return("whsec_live")
    allow(StripeMode).to receive(:webhook_secrets).and_return(%w[whsec_test whsec_live])
    allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
  end

  def post_webhook(event)
    post "/api/v1/webhooks/stripe",
         params: { type: event.type }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "sig" }
  end

  describe "dual webhook secret verification" do
    let(:subscription) do
      double(
        customer: "cus_existing",
        items: double(data: [double(price: double(id: "price_pro_monthly"))])
      )
    end

    let(:event) do
      double(id: "evt_subscription_updated", type: "customer.subscription.updated", data: double(object: subscription))
    end

    before do
      user.update!(stripe_customer_id: "cus_existing")
    end

    it "accepts events verified with the test webhook secret" do
      allow(Stripe::Webhook).to receive(:construct_event)
        .with(anything, "sig", "whsec_test")
        .and_return(event)
      allow(Stripe::Webhook).to receive(:construct_event)
        .with(anything, "sig", "whsec_live")
        .and_raise(Stripe::SignatureVerificationError.new("bad sig", "sig"))

      post_webhook(event)
      expect(response).to have_http_status(:ok)
      expect(user.reload.subscription_tier).to eq("pro")
    end

    it "accepts events verified with the live webhook secret" do
      allow(Stripe::Webhook).to receive(:construct_event)
        .with(anything, "sig", "whsec_test")
        .and_raise(Stripe::SignatureVerificationError.new("bad sig", "sig"))
      allow(Stripe::Webhook).to receive(:construct_event)
        .with(anything, "sig", "whsec_live")
        .and_return(event)
      allow(ENV).to receive(:[]).with("STRIPE_SECRET_KEY_LIVE").and_return("sk_live")
      allow(Stripe::Subscription).to receive(:retrieve).and_return(subscription)

      post_webhook(event)
      expect(response).to have_http_status(:ok)
      expect(user.reload.subscription_tier).to eq("pro")
    end
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
        items: double(data: [double(price: double(id: "price_pro_monthly"))])
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
      expect(user.subscription_tier).to eq("pro")
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

    it "maps legacy starter price to starter tier" do
      post_webhook(event)
      expect(response).to have_http_status(:ok)
      expect(user.reload.subscription_tier).to eq("starter")
    end
  end

  describe "customer.subscription.deleted" do
    let(:subscription) { double(customer: "cus_existing") }
    let(:event) { double(id: "evt_subscription_deleted", type: "customer.subscription.deleted", data: double(object: subscription)) }

    before do
      user.update!(stripe_customer_id: "cus_existing", subscription_tier: "pro")
    end

    it "downgrades user to free" do
      post_webhook(event)
      expect(response).to have_http_status(:ok)
      expect(user.reload.subscription_tier).to eq("free")
    end
  end
end

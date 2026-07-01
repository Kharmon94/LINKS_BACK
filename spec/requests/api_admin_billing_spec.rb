# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Admin Billing", type: :request do
  let!(:admin) do
    User.create!(
      email: "admin@example.com",
      password: "password123",
      name: "Admin",
      subscription_tier: "enterprise",
      role: "owner",
      admin: true,
      password_set_at: Time.current
    )
  end

  let!(:member) do
    User.create!(
      email: "paid@example.com",
      password: "password123",
      name: "Paid",
      subscription_tier: "starter",
      role: "owner",
      stripe_customer_id: "cus_paid",
      password_set_at: Time.current
    )
  end

  let!(:starter_plan) do
    Plan.create!(
      name: "Starter",
      tier: "starter",
      stripe_price_id_monthly: "price_starter_monthly",
      monthly_amount_cents: 900,
      active: true
    )
  end

  describe "GET /api/v1/admin/billing/overview" do
    before do
      BillingEvent.create!(
        user: member,
        event_type: "invoice.paid",
        tier: "starter",
        amount_cents: 900,
        stripe_customer_id: "cus_paid",
        payload_summary: "$9.00"
      )
    end

    it "returns billing overview for admin" do
      get "/api/v1/admin/billing/overview", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      overview = response.parsed_body["overview"]
      expect(overview["paidSubscribers"]).to eq(2)
      expect(overview["subscribersByTier"]).to be_a(Hash)
      expect(overview["stripeLinkedUsers"]).to eq(1)
      expect(overview["mrrCents"]).to be_a(Integer)
      expect(overview["mrrSource"]).to be_in(%w[stripe fallback])
      expect(overview["stripeMode"]).to be_in(%w[test live])
      expect(overview["recentEvents"]).to be_an(Array)
      expect(overview["recentEvents"].first).to include(
        "eventType" => "invoice.paid",
        "email" => member.email,
        "amountFormatted" => "$9.00"
      )
    end

    it "forbids non-admin" do
      get "/api/v1/admin/billing/overview", headers: auth_headers(member)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/admin/billing/stripe_mode" do
    it "returns stripe mode for admin" do
      get "/api/v1/admin/billing/stripe_mode", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["live"]).to be_in([true, false])
      expect(body["source"]).to be_in(%w[database env])
      expect(body).to include("testConfigured", "liveConfigured", "testPublishableConfigured", "livePublishableConfigured")
    end

    it "forbids non-admin" do
      get "/api/v1/admin/billing/stripe_mode", headers: auth_headers(member)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/admin/billing/stripe_mode" do
    it "updates stripe mode for admin" do
      patch "/api/v1/admin/billing/stripe_mode",
            params: { live: true },
            headers: auth_headers(admin),
            as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["live"]).to eq(true)
      expect(AppSetting.get("stripe_live_mode")).to eq("1")
    end

    it "forbids non-admin" do
      patch "/api/v1/admin/billing/stripe_mode",
            params: { live: false },
            headers: auth_headers(member),
            as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/admin/billing/lookup" do
    it "finds user by email with subscription fields when Stripe is configured" do
      allow(StripeMode).to receive(:secret_key).and_return("sk_test")
      sub = double(
        status: "active",
        current_period_end: 1_735_689_600,
        cancel_at_period_end: false
      )
      allow(Stripe::Subscription).to receive(:list)
        .with({ customer: "cus_paid", status: "all", limit: 1 }, { api_key: "sk_test" })
        .and_return(double(data: [sub]))

      get "/api/v1/admin/billing/lookup",
          params: { email: "paid@example.com" },
          headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body["user"]
      expect(body["stripeCustomerId"]).to eq("cus_paid")
      expect(body["hasStripeCustomer"]).to eq(true)
      expect(body["subscriptionStatus"]).to eq("active")
      expect(body["currentPeriodEnd"]).to be_present
      expect(body["cancelAtPeriodEnd"]).to eq(false)
    end

    it "returns 404 for unknown email" do
      get "/api/v1/admin/billing/lookup",
          params: { email: "missing@example.com" },
          headers: auth_headers(admin)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/admin/billing/portal_session" do
    it "creates a Stripe billing portal session for the user" do
      allow(StripeMode).to receive(:secret_key).and_return("sk_test")
      session = double(url: "https://billing.stripe.com/session/test")
      expect(Stripe::BillingPortal::Session).to receive(:create)
        .with(
          hash_including(customer: "cus_paid"),
          { api_key: "sk_test" }
        )
        .and_return(session)

      post "/api/v1/admin/billing/portal_session",
           params: { user_id: member.id },
           headers: auth_headers(admin),
           as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["url"]).to eq("https://billing.stripe.com/session/test")
    end

    it "forbids non-admin" do
      post "/api/v1/admin/billing/portal_session",
           params: { user_id: member.id },
           headers: auth_headers(member),
           as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 503 when Stripe is not configured" do
      allow(StripeMode).to receive(:secret_key).and_return(nil)

      post "/api/v1/admin/billing/portal_session",
           params: { user_id: member.id },
           headers: auth_headers(admin),
           as: :json
      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe "POST /api/v1/admin/billing/cancel_subscription" do
    let(:subscription) { double(id: "sub_123") }

    before do
      allow(StripeMode).to receive(:secret_key).and_return("sk_test")
      allow(Stripe::Subscription).to receive(:list)
        .with({ customer: "cus_paid", status: "active", limit: 1 }, { api_key: "sk_test" })
        .and_return(double(data: [subscription]))
    end

    it "sets cancel_at_period_end on the active subscription" do
      expect(Stripe::Subscription).to receive(:update)
        .with("sub_123", { cancel_at_period_end: true }, { api_key: "sk_test" })

      post "/api/v1/admin/billing/cancel_subscription",
           params: { user_id: member.id },
           headers: auth_headers(admin),
           as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]["email"]).to eq(member.email)
    end

    it "cancels immediately when requested" do
      expect(Stripe::Subscription).to receive(:cancel)
        .with("sub_123", {}, { api_key: "sk_test" })

      post "/api/v1/admin/billing/cancel_subscription",
           params: { user_id: member.id, immediate: true },
           headers: auth_headers(admin),
           as: :json
      expect(response).to have_http_status(:ok)
      expect(member.reload.subscription_tier).to eq("free")
    end

    it "forbids non-admin" do
      post "/api/v1/admin/billing/cancel_subscription",
           params: { user_id: member.id },
           headers: auth_headers(member),
           as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end

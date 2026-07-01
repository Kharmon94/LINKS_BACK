# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Plans", type: :request do
  let!(:pro_plan) do
    Plan.create!(
      name: "Pro",
      tier: "pro",
      stripe_price_id_monthly: "price_pro_monthly",
      stripe_price_id_yearly: "price_pro_yearly",
      active: true
    )
  end

  around do |example|
    original = ENV.to_h.slice("STRIPE_PUBLISHABLE_KEY", "STRIPE_PUBLISHABLE_KEY_LIVE")
    AppSetting.where(key: "stripe_live_mode").delete_all
    example.run
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    AppSetting.where(key: "stripe_live_mode").delete_all
  end

  describe "GET /api/v1/plans" do
    it "returns active plans with stripe publishable key for test mode" do
      ENV["STRIPE_PUBLISHABLE_KEY"] = "pk_test_abc"

      get "/api/v1/plans"
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["stripePublishableKey"]).to eq("pk_test_abc")
      pro = body["plans"].find { |p| p["tier"] == "pro" }
      expect(pro).to include(
        "stripePriceIdMonthly" => "price_pro_monthly",
        "stripePriceIdYearly" => "price_pro_yearly"
      )
      expect(body["tiers"].map { |t| t["tier"] }).to include("free", "enterprise")
    end

    it "returns live publishable key when live mode is active" do
      AppSetting.set("stripe_live_mode", "1")
      ENV["STRIPE_PUBLISHABLE_KEY"] = "pk_test_abc"
      ENV["STRIPE_PUBLISHABLE_KEY_LIVE"] = "pk_live_xyz"
      pro_plan.update!(
        stripe_price_id_monthly_live: "price_pro_monthly_live",
        stripe_price_id_yearly_live: "price_pro_yearly_live"
      )

      get "/api/v1/plans"
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["stripePublishableKey"]).to eq("pk_live_xyz")
      pro = body["plans"].find { |p| p["tier"] == "pro" }
      expect(pro["stripePriceIdMonthly"]).to eq("price_pro_monthly_live")
      expect(pro["stripePriceIdYearly"]).to eq("price_pro_yearly_live")
    end
  end
end

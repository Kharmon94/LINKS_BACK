# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeMode do
  around do |example|
    original = ENV.to_h.slice(
      "STRIPE_LIVE_MODE",
      "STRIPE_SECRET_KEY",
      "STRIPE_SECRET_KEY_LIVE",
      "STRIPE_PUBLISHABLE_KEY",
      "STRIPE_PUBLISHABLE_KEY_LIVE"
    )
    AppSetting.where(key: "stripe_live_mode").delete_all
    example.run
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    AppSetting.where(key: "stripe_live_mode").delete_all
  end

  it "returns test publishable key in test mode" do
    ENV["STRIPE_PUBLISHABLE_KEY"] = "pk_test_abc"
    ENV["STRIPE_PUBLISHABLE_KEY_LIVE"] = "pk_live_xyz"

    expect(described_class.publishable_key).to eq("pk_test_abc")
  end

  it "returns live publishable key in live mode" do
    AppSetting.set("stripe_live_mode", "1")
    ENV["STRIPE_PUBLISHABLE_KEY"] = "pk_test_abc"
    ENV["STRIPE_PUBLISHABLE_KEY_LIVE"] = "pk_live_xyz"

    expect(described_class.publishable_key).to eq("pk_live_xyz")
  end

  it "tracks publishable key configuration separately from secret keys" do
    ENV.delete("STRIPE_PUBLISHABLE_KEY")
    ENV["STRIPE_SECRET_KEY"] = "sk_test"
    ENV["STRIPE_PUBLISHABLE_KEY_LIVE"] = "pk_live_xyz"

    expect(described_class.test_configured?).to be(true)
    expect(described_class.test_publishable_configured?).to be(false)
    expect(described_class.live_publishable_configured?).to be(true)
  end

  describe "readiness" do
    let!(:pro_plan) do
      Plan.create!(
        name: "Pro",
        tier: "pro",
        stripe_price_id_monthly: "price_m",
        stripe_price_id_yearly: "price_y",
        stripe_price_id_monthly_live: "price_m_live",
        stripe_price_id_yearly_live: "price_y_live",
        active: true
      )
    end

    it "reports mode readiness from env vars and pro plan prices" do
      ENV["STRIPE_SECRET_KEY"] = "sk_test"
      ENV["STRIPE_PUBLISHABLE_KEY"] = "pk_test"
      ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_test"
      ENV["STRIPE_PRICE_PRO_MONTHLY"] = "price_m"
      ENV["STRIPE_PRICE_PRO_YEARLY"] = "price_y"
      ENV["STRIPE_SECRET_KEY_LIVE"] = "sk_live"
      ENV["STRIPE_PUBLISHABLE_KEY_LIVE"] = "pk_live"
      ENV["STRIPE_WEBHOOK_SECRET_LIVE"] = "whsec_live"
      ENV["STRIPE_PRICE_PRO_MONTHLY_LIVE"] = "price_m_live"
      ENV["STRIPE_PRICE_PRO_YEARLY_LIVE"] = "price_y_live"

      report = described_class.readiness_report
      expect(report[:test][:ready]).to be(true)
      expect(report[:live][:ready]).to be(true)
      expect(described_class.current_mode_ready?).to be(true)
    end

    it "lists missing env vars for a mode" do
      ENV.delete("STRIPE_SECRET_KEY_LIVE")
      missing = described_class.missing_env_vars_for_mode(live: true)
      expect(missing).to include("STRIPE_SECRET_KEY_LIVE")
    end
  end
end

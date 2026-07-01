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
end

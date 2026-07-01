# frozen_string_literal: true

require "rails_helper"

RSpec.describe Plan do
  let!(:pro_plan) do
    described_class.create!(
      name: "Pro",
      tier: "pro",
      stripe_price_id_monthly: "price_pro_monthly",
      stripe_price_id_yearly: "price_pro_yearly",
      stripe_price_id_monthly_live: "price_pro_monthly_live",
      stripe_price_id_yearly_live: "price_pro_yearly_live",
      active: true
    )
  end

  let!(:starter_plan) do
    described_class.create!(
      name: "Starter",
      tier: "starter",
      stripe_price_id_monthly: "price_starter_monthly",
      stripe_price_id_yearly: "price_starter_yearly",
      active: false
    )
  end

  describe ".tier_for_price_id" do
    it "maps test and live price IDs regardless of active Stripe mode" do
      AppSetting.set("stripe_live_mode", "1")

      expect(described_class.tier_for_price_id("price_pro_monthly")).to eq("pro")
      expect(described_class.tier_for_price_id("price_pro_monthly_live")).to eq("pro")
      expect(described_class.tier_for_price_id("price_starter_yearly")).to eq("starter")
      expect(described_class.tier_for_price_id("price_unknown")).to be_nil
    end
  end
end

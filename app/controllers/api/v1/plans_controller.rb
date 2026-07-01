# frozen_string_literal: true

module Api
  module V1
    class PlansController < ApplicationController
      TIER_FEATURES = {
        "pro" => [
          "Unlimited links & campaigns",
          "Custom domain",
          "Workspaces & team",
          "Advanced analytics",
          "Randomizer split testing"
        ],
        "starter" => [
          "Up to 20 links",
          "2 campaigns",
          "Tap analytics dashboard",
          "Multiple devices"
        ],
        "growth" => [
          "Unlimited links & campaigns",
          "Custom domain",
          "Workspaces & team",
          "Advanced analytics",
          "Randomizer split testing"
        ]
      }.freeze

      TIER_PRICES = {
        "pro" => { monthly: 50, yearly: 500 },
        "starter" => { monthly: 15, yearly: 150 },
        "growth" => { monthly: 150, yearly: 1500 }
      }.freeze

      def index
        plans = Plan.where(active: true).order(:tier)
        render json: {
          plans: plans.map { |p| plan_json(p) },
          tiers: static_tiers
        }
      end

      private

      def plan_json(plan)
        monthly_id, yearly_id = plan.stripe_price_ids_for_mode
        {
          id: plan.id,
          name: plan.name,
          tier: plan.tier,
          stripePriceIdMonthly: monthly_id,
          stripePriceIdYearly: yearly_id,
          prices: TIER_PRICES[plan.tier],
          features: TIER_FEATURES[plan.tier] || []
        }
      end

      def static_tiers
        [
          {
            tier: "free",
            name: "Free",
            prices: { monthly: 0, yearly: 0 },
            features: ["1 link", "Basic analytics"],
            checkout: false
          },
          {
            tier: "enterprise",
            name: "Enterprise",
            prices: nil,
            features: TIER_FEATURES["pro"] + ["Dedicated support", "Custom deployments"],
            checkout: false,
            salesLed: true
          }
        ]
      end
    end
  end
end

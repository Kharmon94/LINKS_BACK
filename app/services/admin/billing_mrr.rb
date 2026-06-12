# frozen_string_literal: true

module Admin
  class BillingMrr
    def self.estimate_cents(tier_counts)
      prices = monthly_prices_cents
      source = prices.values.any?(&:positive?) && StripeMode.secret_key.present? ? "stripe" : "fallback"

      cents = tier_counts.sum do |tier, count|
        next 0 if tier.in?(%w[free enterprise])

        (prices[tier] || 0) * count
      end

      { cents: cents, source: source }
    end

    def self.monthly_prices_cents
      cache = {}
      Plan.find_each do |plan|
        cache[plan.tier] = price_cents_for_plan(plan)
      end
      cache
    end

    def self.price_cents_for_plan(plan)
      return plan.monthly_amount_cents.to_i if plan.monthly_amount_cents.present? && StripeMode.secret_key.blank?

      price_id = plan.stripe_price_ids_for_mode.compact.find { |id| monthly_price_id?(id, plan) }
      price_id ||= plan.stripe_price_ids_for_mode.compact.first
      return plan.monthly_amount_cents.to_i if price_id.blank?

      retrieve_monthly_cents(price_id, plan)
    rescue Stripe::StripeError
      plan.monthly_amount_cents.to_i
    end

    def self.monthly_price_id?(price_id, plan)
      [plan.stripe_price_id_monthly, plan.stripe_price_id_monthly_live].compact.include?(price_id)
    end

    def self.retrieve_monthly_cents(price_id, plan)
      key = StripeMode.secret_key
      return plan.monthly_amount_cents.to_i if key.blank?

      price = Stripe::Price.retrieve(price_id, { api_key: key })
      unit = price.unit_amount.to_i
      interval = price.recurring&.interval
      case interval
      when "month" then unit
      when "year" then (unit / 12.0).round
      else plan.monthly_amount_cents.to_i
      end
    end

    private_class_method :monthly_price_id?, :retrieve_monthly_cents, :price_cents_for_plan
  end
end

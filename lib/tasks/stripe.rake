# frozen_string_literal: true

namespace :stripe do
  desc "Sync Plan records to Stripe (test or live via STRIPE_LIVE_MODE)"
  task sync_plans: :environment do
    key = StripeMode.secret_key
    unless key.present?
      puts "Skipping stripe:sync_plans (no STRIPE_SECRET_KEY)"
      next
    end

    Plan.where(active: true).find_each do |plan|
      product = Stripe::Product.create({ name: plan.name }, { api_key: key })
      monthly_id = plan.stripe_price_id_monthly.presence
      if monthly_id.blank?
        price = Stripe::Price.create(
          {
            product: product.id,
            unit_amount: 1000,
            currency: "usd",
            recurring: { interval: "month" }
          },
          { api_key: key }
        )
        plan.update!(stripe_price_id_monthly: price.id)
      end
      puts "Synced plan #{plan.name}"
    end
  end
end

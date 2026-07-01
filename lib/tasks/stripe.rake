# frozen_string_literal: true

namespace :stripe do
  desc "Sync Plan records to Stripe (test or live via StripeMode)"
  task sync_plans: :environment do
    key = StripeMode.secret_key
    unless key.present?
      puts "Skipping stripe:sync_plans (no STRIPE_SECRET_KEY)"
      next
    end

    Plan.where(active: true).find_each do |plan|
      monthly_id, yearly_id = plan.stripe_price_ids_for_mode
      if monthly_id.present? && yearly_id.present?
        puts "Skipping plan #{plan.name} (price IDs already set)"
        next
      end

      product = Stripe::Product.create({ name: plan.name }, { api_key: key })
      if monthly_id.blank?
        price = Stripe::Price.create(
          {
            product: product.id,
            unit_amount: 5000,
            currency: "usd",
            recurring: { interval: "month" }
          },
          { api_key: key }
        )
        if StripeMode.live?
          plan.update!(stripe_price_id_monthly_live: price.id)
        else
          plan.update!(stripe_price_id_monthly: price.id)
        end
      end

      if yearly_id.blank?
        price = Stripe::Price.create(
          {
            product: product.id,
            unit_amount: 50_000,
            currency: "usd",
            recurring: { interval: "year" }
          },
          { api_key: key }
        )
        if StripeMode.live?
          plan.update!(stripe_price_id_yearly_live: price.id)
        else
          plan.update!(stripe_price_id_yearly: price.id)
        end
      end

      puts "Synced plan #{plan.name}"
    end
  end
end

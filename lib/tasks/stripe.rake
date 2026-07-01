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

  desc "Verify Stripe env vars and Pro plan readiness for test and live modes"
  task verify: :environment do
    modes = { test: false, live: true }
    all_ok = true

    modes.each do |label, live|
      missing = StripeMode.missing_env_vars_for_mode(live: live)
      plan_ok = StripeMode.pro_plan_has_prices_for_mode?(live: live)
      ready = missing.empty? && plan_ok

      puts "\n#{label.to_s.upcase} mode:"
      if missing.any?
        puts "  Missing env: #{missing.join(', ')}"
        all_ok = false
      else
        puts "  Env vars: OK"
      end
      puts plan_ok ? "  Pro plan price IDs: OK" : "  Pro plan price IDs: MISSING (run db:seed with STRIPE_PRICE_PRO_*)"
      all_ok = false unless plan_ok
      puts ready ? "  Ready: yes" : "  Ready: no"
    end

    current = StripeMode.live? ? "live" : "test"
    puts "\nActive mode: #{current} (#{StripeMode.mode_source})"
    puts StripeMode.current_mode_ready? ? "Current mode ready: yes" : "Current mode ready: no"

    abort "Stripe verify failed" unless all_ok && StripeMode.current_mode_ready?
    puts "\nStripe verify passed"
  end
end

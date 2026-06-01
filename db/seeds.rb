# frozen_string_literal: true

# Idempotent production seed: removes legacy placeholder plans only, then applies
# config from explicit env vars (no fake Stripe price IDs). Users are never deleted.

LEGACY_PLAN_PRICE_IDS = %w[price_starter_monthly price_starter_yearly].freeze

legacy_plans = Plan.where(stripe_price_id_monthly: LEGACY_PLAN_PRICE_IDS)
                   .or(Plan.where(stripe_price_id_yearly: LEGACY_PLAN_PRICE_IDS))
removed_plans = legacy_plans.count
legacy_plans.find_each(&:destroy!)
puts "Removed #{removed_plans} legacy placeholder plan(s)" if removed_plans.positive?

monthly = ENV["STRIPE_PRICE_STARTER_MONTHLY"].to_s.strip.presence
yearly = ENV["STRIPE_PRICE_STARTER_YEARLY"].to_s.strip.presence
monthly_live = ENV["STRIPE_PRICE_STARTER_MONTHLY_LIVE"].to_s.strip.presence
yearly_live = ENV["STRIPE_PRICE_STARTER_YEARLY_LIVE"].to_s.strip.presence

if monthly.present? || yearly.present? || monthly_live.present? || yearly_live.present?
  plan = Plan.find_or_initialize_by(name: "Starter")
  plan.stripe_price_id_monthly = monthly if monthly
  plan.stripe_price_id_yearly = yearly if yearly
  plan.stripe_price_id_monthly_live = monthly_live if monthly_live
  plan.stripe_price_id_yearly_live = yearly_live if yearly_live
  plan.active = true
  plan.save!
  puts "Ensured Starter plan from STRIPE_PRICE_STARTER_* env"
else
  puts "Skipping plan seed (set STRIPE_PRICE_STARTER_MONTHLY / STRIPE_PRICE_STARTER_YEARLY)"
end

email = ENV["ADMIN_SEED_EMAIL"].to_s.strip.presence
password = ENV["ADMIN_SEED_PASSWORD"].to_s.strip.presence
if email.present? && password.present?
  user = User.where("lower(email) = ?", email.downcase).first_or_initialize
  user.email = email if user.email.blank?
  user.assign_attributes(
    name: user.name.presence || "Admin",
    password: password,
    admin: true,
    subscription_tier: "enterprise",
    role: "owner"
  )
  user.save!
  puts "Ensured admin: #{email}"
else
  puts "Skipping admin seed (set ADMIN_SEED_EMAIL and ADMIN_SEED_PASSWORD)"
end

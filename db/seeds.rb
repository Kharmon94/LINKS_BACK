# frozen_string_literal: true

Plan.find_or_create_by!(name: "Starter") do |p|
  p.stripe_price_id_monthly = ENV["STRIPE_PRICE_STARTER_MONTHLY"].presence || "price_starter_monthly"
  p.stripe_price_id_yearly = ENV["STRIPE_PRICE_STARTER_YEARLY"].presence || "price_starter_yearly"
  p.stripe_price_id_monthly_live = ENV["STRIPE_PRICE_STARTER_MONTHLY_LIVE"].presence
  p.stripe_price_id_yearly_live = ENV["STRIPE_PRICE_STARTER_YEARLY_LIVE"].presence
  p.active = true
end

email = ENV["ADMIN_SEED_EMAIL"].to_s.strip.presence
password = ENV["ADMIN_SEED_PASSWORD"].to_s.strip.presence
if email.present? && password.present?
  user = User.where("lower(email) = ?", email.downcase).first_or_initialize
  user.email = email if user.new_record?
  user.assign_attributes(
    name: user.name.presence || "Admin",
    password: password,
    admin: true,
    subscription_tier: "enterprise",
    role: "owner"
  )
  user.save!
  puts "Seeded admin: #{email}"
else
  puts "Skipping admin seed (set ADMIN_SEED_EMAIL and ADMIN_SEED_PASSWORD)"
end

FactoryBot.define do
  factory :plan do
    name { "Starter" }
    tier { "starter" }
    stripe_price_id_monthly { "price_starter_monthly" }
    stripe_price_id_yearly { "price_starter_yearly" }
    active { true }
  end
end

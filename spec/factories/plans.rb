FactoryBot.define do
  factory :plan do
    name { "MyString" }
    stripe_price_id_monthly { "MyString" }
    stripe_price_id_yearly { "MyString" }
    stripe_price_id_monthly_live { "MyString" }
    stripe_price_id_yearly_live { "MyString" }
    interval { "MyString" }
    active { false }
  end
end

FactoryBot.define do
  factory :link do
    user { nil }
    destination_url { "MyString" }
    short_code { "MyString" }
    name { "MyString" }
    clicks_count { 1 }
  end
end

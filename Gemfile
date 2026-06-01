source "https://rubygems.org"

gem "rails", "8.1.3"
gem "sqlite3", ">= 2.1"
gem "pg", group: :production
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "rack-cors"
gem "rack-attack"
gem "jwt"
gem "devise"
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"
gem "cancancan"
gem "stripe"
gem "webpush", ">= 1.0"

gem "kamal", require: false
gem "thruster", require: false

group :production do
  gem "aws-sdk-s3", require: false
end

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails"
  gem "factory_bot_rails"
end

group :development do
  gem "letter_opener"
  gem "letter_opener_web"
end


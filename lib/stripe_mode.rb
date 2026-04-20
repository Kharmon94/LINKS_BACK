# frozen_string_literal: true

module StripeMode
  module_function

  def live?
    ActiveModel::Type::Boolean.new.cast(ENV["STRIPE_LIVE_MODE"])
  end

  def secret_key
    if live?
      ENV["STRIPE_SECRET_KEY_LIVE"].presence || ENV["STRIPE_SECRET_KEY"]
    else
      ENV["STRIPE_SECRET_KEY"]
    end
  end

  def webhook_secret
    if live?
      ENV["STRIPE_WEBHOOK_SECRET_LIVE"].presence || ENV["STRIPE_WEBHOOK_SECRET"]
    else
      ENV["STRIPE_WEBHOOK_SECRET"]
    end
  end
end

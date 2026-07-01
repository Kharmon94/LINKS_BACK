# frozen_string_literal: true

module StripeMode
  module_function

  def live?
    db_value = AppSetting.get("stripe_live_mode")
    unless db_value.nil?
      return ActiveModel::Type::Boolean.new.cast(db_value)
    end

    ActiveModel::Type::Boolean.new.cast(ENV["STRIPE_LIVE_MODE"]) == true
  end

  def mode_source
    AppSetting.get("stripe_live_mode").nil? ? "env" : "database"
  end

  def test_configured?
    ENV["STRIPE_SECRET_KEY"].present?
  end

  def live_configured?
    ENV["STRIPE_SECRET_KEY_LIVE"].present?
  end

  def test_publishable_configured?
    ENV["STRIPE_PUBLISHABLE_KEY"].present?
  end

  def live_publishable_configured?
    ENV["STRIPE_PUBLISHABLE_KEY_LIVE"].present?
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

  def publishable_key
    if live?
      ENV["STRIPE_PUBLISHABLE_KEY_LIVE"].presence || ENV["STRIPE_PUBLISHABLE_KEY"]
    else
      ENV["STRIPE_PUBLISHABLE_KEY"]
    end
  end

  def webhook_secrets
    [ENV["STRIPE_WEBHOOK_SECRET"], ENV["STRIPE_WEBHOOK_SECRET_LIVE"]].compact.uniq
  end

  def secret_key_for_webhook_secret(webhook_secret_used)
    if webhook_secret_used.present? && webhook_secret_used == ENV["STRIPE_WEBHOOK_SECRET_LIVE"].presence
      ENV["STRIPE_SECRET_KEY_LIVE"].presence || ENV["STRIPE_SECRET_KEY"]
    else
      ENV["STRIPE_SECRET_KEY"]
    end
  end
end

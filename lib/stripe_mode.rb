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

  MODE_ENV_KEYS = {
    test: {
      secret: "STRIPE_SECRET_KEY",
      publishable: "STRIPE_PUBLISHABLE_KEY",
      webhook: "STRIPE_WEBHOOK_SECRET",
      pro_monthly: "STRIPE_PRICE_PRO_MONTHLY",
      pro_yearly: "STRIPE_PRICE_PRO_YEARLY"
    },
    live: {
      secret: "STRIPE_SECRET_KEY_LIVE",
      publishable: "STRIPE_PUBLISHABLE_KEY_LIVE",
      webhook: "STRIPE_WEBHOOK_SECRET_LIVE",
      pro_monthly: "STRIPE_PRICE_PRO_MONTHLY_LIVE",
      pro_yearly: "STRIPE_PRICE_PRO_YEARLY_LIVE"
    }
  }.freeze

  def mode_readiness(live:)
    keys = MODE_ENV_KEYS[live ? :live : :test]
    {
      secretKey: ENV[keys[:secret]].present?,
      publishableKey: ENV[keys[:publishable]].present?,
      webhookSecret: ENV[keys[:webhook]].present?,
      proMonthlyPriceEnv: ENV[keys[:pro_monthly]].present?,
      proYearlyPriceEnv: ENV[keys[:pro_yearly]].present?
    }
  end

  def pro_plan_has_prices_for_mode?(live: live?)
    plan = Plan.find_by(tier: "pro", active: true)
    return false unless plan

    monthly, yearly = if live
                        [plan.stripe_price_id_monthly_live.presence || plan.stripe_price_id_monthly,
                         plan.stripe_price_id_yearly_live.presence || plan.stripe_price_id_yearly]
                      else
                        [plan.stripe_price_id_monthly, plan.stripe_price_id_yearly]
                      end
    monthly.present? && yearly.present?
  end

  def mode_ready?(live:)
    mode_readiness(live: live).values.all? && pro_plan_has_prices_for_mode?(live: live)
  end

  def current_mode_ready?
    mode_ready?(live: live?)
  end

  def readiness_report
    {
      currentModeReady: current_mode_ready?,
      test: mode_readiness(live: false).merge(
        ready: mode_ready?(live: false),
        proPlanPrices: pro_plan_has_prices_for_mode?(live: false)
      ),
      live: mode_readiness(live: true).merge(
        ready: mode_ready?(live: true),
        proPlanPrices: pro_plan_has_prices_for_mode?(live: true)
      )
    }
  end

  def missing_env_vars_for_mode(live:)
    keys = MODE_ENV_KEYS[live ? :live : :test]
    keys.values.reject { |name| ENV[name].present? }
  end
end

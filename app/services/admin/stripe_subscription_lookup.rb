# frozen_string_literal: true

module Admin
  class StripeSubscriptionLookup
    def self.for_user(user)
      return empty unless user.stripe_customer_id.present?

      key = StripeMode.secret_key
      return empty if key.blank?

      subs = Stripe::Subscription.list(
        { customer: user.stripe_customer_id, status: "all", limit: 1 },
        { api_key: key }
      )
      sub = subs.data.first
      return empty if sub.blank?

      {
        subscriptionStatus: sub.status,
        currentPeriodEnd: Time.at(sub.current_period_end).iso8601,
        cancelAtPeriodEnd: sub.cancel_at_period_end == true
      }
    rescue Stripe::StripeError
      empty
    end

    def self.empty
      {
        subscriptionStatus: nil,
        currentPeriodEnd: nil,
        cancelAtPeriodEnd: false
      }
    end

    private_class_method :empty
  end
end

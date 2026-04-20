# frozen_string_literal: true

module Api
  module V1
    class StripeWebhooksController < ApplicationController
      def create
        payload = request.body.read
        sig = request.env["HTTP_STRIPE_SIGNATURE"]
        secret = StripeMode.webhook_secret
        return head :bad_request if secret.blank?

        event = Stripe::Webhook.construct_event(payload, sig, secret)
        handle_event(event)
        head :ok
      rescue JSON::ParserError, Stripe::SignatureVerificationError
        head :bad_request
      end

      private

      def handle_event(event)
        case event.type
        when "customer.subscription.updated", "customer.subscription.created"
          sub = event.data.object
          sync_subscription_tier(sub)
        when "customer.subscription.deleted"
          sub = event.data.object
          user = User.find_by(stripe_customer_id: sub.customer)
          user&.update!(subscription_tier: "free")
        when "invoice.paid", "invoice.payment_failed"
          inv = event.data.object
          sid = SubscriptionIdFromInvoice.call(inv)
          return if sid.blank?

          key = StripeMode.secret_key
          sub = Stripe::Subscription.retrieve(sid, {}, { api_key: key })
          sync_subscription_tier(sub)
        end
      end

      def sync_subscription_tier(sub)
        user = User.find_by(stripe_customer_id: sub.customer)
        return unless user

        tier = map_price_to_tier(sub.items&.data&.first&.price&.id)
        user.update!(subscription_tier: tier) if tier
      end

      def map_price_to_tier(price_id)
        return nil if price_id.blank?

        Plan.find_each do |plan|
          return "starter" if [plan.stripe_price_id_monthly, plan.stripe_price_id_yearly,
                                plan.stripe_price_id_monthly_live, plan.stripe_price_id_yearly_live].compact.include?(price_id)
        end
        "starter"
      end
    end
  end
end

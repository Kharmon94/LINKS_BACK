# frozen_string_literal: true

module Api
  module V1
    class StripeWebhooksController < ApplicationController
      RECORDABLE_EVENTS = %w[
        checkout.session.completed
        customer.subscription.created
        customer.subscription.updated
        customer.subscription.deleted
        invoice.paid
        invoice.payment_failed
      ].freeze

      def create
        payload = request.body.read
        sig = request.env["HTTP_STRIPE_SIGNATURE"]
        event, webhook_secret_used = construct_event_with_dual_secrets(payload, sig)
        return head :bad_request unless event

        @webhook_api_key = StripeMode.secret_key_for_webhook_secret(webhook_secret_used)
        handle_event(event)
        head :ok
      rescue JSON::ParserError
        head :bad_request
      end

      private

      def construct_event_with_dual_secrets(payload, sig)
        StripeMode.webhook_secrets.each do |secret|
          next if secret.blank?

          begin
            event = Stripe::Webhook.construct_event(payload, sig, secret)
            return [event, secret]
          rescue Stripe::SignatureVerificationError
            next
          end
        end
        [nil, nil]
      end

      def handle_event(event)
        case event.type
        when "checkout.session.completed"
          handle_checkout_completed(event.data.object, event)
        when "customer.subscription.updated", "customer.subscription.created"
          sync_subscription_tier(event.data.object, event)
        when "customer.subscription.deleted"
          sub = event.data.object
          user = User.find_by(stripe_customer_id: sub.customer)
          user&.update!(subscription_tier: "free")
          record_billing_event(event, user: user, tier: "free")
        when "invoice.paid", "invoice.payment_failed"
          inv = event.data.object
          sid = SubscriptionIdFromInvoice.call(inv)
          return if sid.blank?

          sub = Stripe::Subscription.retrieve(sid, { api_key: webhook_api_key })
          sync_subscription_tier(sub, event, amount_cents: invoice_amount_cents(inv))
        end
      end

      def handle_checkout_completed(session, event)
        user = User.find_by(id: session.client_reference_id)
        return unless user

        if session.customer.present?
          user.update!(stripe_customer_id: session.customer)
        end

        return if session.subscription.blank?

        sub = Stripe::Subscription.retrieve(session.subscription, { api_key: webhook_api_key })
        sync_subscription_tier(sub, event)
      end

      def sync_subscription_tier(sub, event = nil, amount_cents: nil)
        user = User.find_by(stripe_customer_id: sub.customer)
        return unless user

        tier = map_price_to_tier(sub.items&.data&.first&.price&.id)
        user.update!(subscription_tier: tier) if tier
        record_billing_event(event, user: user, tier: tier || user.subscription_tier, amount_cents: amount_cents) if event
      end

      def record_billing_event(event, user:, tier: nil, amount_cents: nil)
        return unless event && user && RECORDABLE_EVENTS.include?(event.type)

        BillingEvent.record_from_stripe!(event, user: user, tier: tier, amount_cents: amount_cents)
      end

      def invoice_amount_cents(inv)
        return inv.amount_paid if inv.respond_to?(:amount_paid) && inv.amount_paid.to_i.positive?

        inv.amount_due.to_i if inv.respond_to?(:amount_due)
      end

      def map_price_to_tier(price_id)
        return nil if price_id.blank?

        Plan.find_each do |plan|
          next if plan.tier.blank?

          price_ids = [
            plan.stripe_price_id_monthly,
            plan.stripe_price_id_yearly,
            plan.stripe_price_id_monthly_live,
            plan.stripe_price_id_yearly_live
          ].compact
          return plan.tier if price_ids.include?(price_id)
        end

        nil
      end

      def webhook_api_key
        @webhook_api_key.presence || StripeMode.secret_key
      end
    end
  end
end

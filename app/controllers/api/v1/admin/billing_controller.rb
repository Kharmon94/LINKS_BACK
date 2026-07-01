# frozen_string_literal: true

module Api
  module V1
    module Admin
      class BillingController < BaseController
        def overview
          authorize! :read, :admin_billing
          render json: { overview: billing_overview }
        end

        def stripe_mode
          authorize! :read, :admin_billing
          render json: stripe_mode_json
        end

        def update_stripe_mode
          authorize! :update, :admin_billing_stripe_mode
          live = ActiveModel::Type::Boolean.new.cast(params[:live])
          AppSetting.set("stripe_live_mode", live ? "1" : "0")
          render json: stripe_mode_json
        end

        def lookup
          authorize! :read, :admin_billing
          email = params[:email].to_s.strip.downcase
          return render json: { error: "email required" }, status: :unprocessable_entity if email.blank?

          user = User.find_by("lower(email) = ?", email)
          return render json: { error: "User not found" }, status: :not_found unless user

          render json: { user: billing_user_json(user) }
        end

        def portal_session
          authorize! :create, :admin_billing_portal
          user = HasPublicId.find_by_param!(User, params[:user_id])
          key = StripeMode.secret_key
          return head :service_unavailable if key.blank?
          return render json: { error: "No Stripe customer" }, status: :unprocessable_entity if user.stripe_customer_id.blank?

          session = Stripe::BillingPortal::Session.create(
            {
              customer: user.stripe_customer_id,
              return_url: "#{frontend_origin}/admin/billing"
            },
            { api_key: key }
          )
          render json: { url: session.url }
        end

        def cancel_subscription
          authorize! :create, :admin_billing_cancel
          user = HasPublicId.find_by_param!(User, params[:user_id])
          key = StripeMode.secret_key
          return head :service_unavailable if key.blank?
          return render json: { error: "No Stripe customer" }, status: :unprocessable_entity if user.stripe_customer_id.blank?

          subs = Stripe::Subscription.list(
            { customer: user.stripe_customer_id, status: "active", limit: 1 },
            { api_key: key }
          )
          sub = subs.data.first
          return render json: { error: "No active subscription" }, status: :unprocessable_entity unless sub

          if ActiveModel::Type::Boolean.new.cast(params[:immediate])
            Stripe::Subscription.cancel(sub.id, {}, { api_key: key })
            user.update!(subscription_tier: "free")
          else
            Stripe::Subscription.update(sub.id, { cancel_at_period_end: true }, { api_key: key })
          end

          render json: { user: billing_user_json(user.reload, include_subscription: false) }
        end

        private

        def billing_overview
          tier_counts = User.where.not(subscription_tier: "free").group(:subscription_tier).count
          mrr = ::Admin::BillingMrr.estimate_cents(tier_counts)

          {
            mrrCents: mrr[:cents],
            mrrFormatted: format_money(mrr[:cents]),
            mrrSource: mrr[:source],
            stripeMode: StripeMode.live? ? "live" : "test",
            subscribersByTier: User::TIER_LIMITS.keys.index_with { |tier| tier_counts[tier] || 0 },
            paidSubscribers: tier_counts.values.sum,
            stripeLinkedUsers: User.where.not(stripe_customer_id: nil).count,
            recentEvents: BillingEvent.includes(:user).recent.limit(20).map(&:as_json_for_admin)
          }
        end

        def stripe_mode_json
          readiness = StripeMode.readiness_report
          {
            live: StripeMode.live?,
            source: StripeMode.mode_source,
            testConfigured: StripeMode.test_configured?,
            liveConfigured: StripeMode.live_configured?,
            testPublishableConfigured: StripeMode.test_publishable_configured?,
            livePublishableConfigured: StripeMode.live_publishable_configured?,
            publishableKey: StripeMode.publishable_key,
            currentModeReady: readiness[:currentModeReady],
            readiness: readiness
          }
        end

        def billing_user_json(user, include_subscription: true)
          base = {
            id: user.public_id,
            publicId: user.public_id,
            email: user.email,
            name: user.name,
            subscriptionTier: user.subscription_tier,
            stripeCustomerId: user.stripe_customer_id,
            hasStripeCustomer: user.stripe_customer_id.present?
          }
          return base unless include_subscription

          base.merge(::Admin::StripeSubscriptionLookup.for_user(user))
        end

        def format_money(cents)
          "$#{'%.2f' % (cents / 100.0)}"
        end

        def frontend_origin
          ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").chomp("/")
        end
      end
    end
  end
end

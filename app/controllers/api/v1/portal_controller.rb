# frozen_string_literal: true

module Api
  module V1
    class PortalController < BaseController
      def create_session
        key = StripeMode.secret_key
        return head :service_unavailable if key.blank?
        return render json: { error: "No Stripe customer" }, status: :unprocessable_entity if current_user.stripe_customer_id.blank?

        session = Stripe::BillingPortal::Session.create(
          {
            customer: current_user.stripe_customer_id,
            return_url: "#{frontend_origin}/settings"
          },
          { api_key: key }
        )
        render json: { url: session.url }
      end

      private

      def frontend_origin
        ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").chomp("/")
      end
    end
  end
end

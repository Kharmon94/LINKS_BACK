# frozen_string_literal: true

module Api
  module V1
    class CheckoutController < BaseController
      def create_session
        authorize! :create, :checkout
        key = StripeMode.secret_key
        return head :service_unavailable if key.blank?

        price_id = params[:price_id].presence
        return render json: { error: "price_id required" }, status: :unprocessable_entity if price_id.blank?
        unless Plan.active_price_id_for_mode?(price_id)
          return render json: { error: "Invalid price_id" }, status: :unprocessable_entity
        end

        session_params = {
          mode: "subscription",
          line_items: [{ price: price_id, quantity: 1 }],
          success_url: "#{frontend_origin}/dashboard?checkout=success",
          cancel_url: "#{frontend_origin}/pricing?checkout=cancel",
          client_reference_id: current_user.id.to_s
        }
        if current_user.stripe_customer_id.present?
          session_params[:customer] = current_user.stripe_customer_id
        else
          session_params[:customer_email] = current_user.email
        end

        session = Stripe::Checkout::Session.create(session_params, { api_key: key })
        render json: { url: session.url }
      end

      private

      def frontend_origin
        ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").chomp("/")
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class PushSubscriptionsController < BaseController
      def create
        sub = params[:subscription].presence || params
        endpoint = sub[:endpoint].to_s
        keys = sub[:keys] || {}
        p256dh = keys[:p256dh].to_s
        auth = keys[:auth].to_s

        record = current_user.web_push_subscriptions.find_or_initialize_by(endpoint: endpoint)
        record.assign_attributes(
          p256dh: p256dh,
          auth: auth,
          user_agent: request.user_agent.to_s,
          expires_at: sub[:expirationTime]
        )

        if record.save
          render json: { ok: true }, status: :created
        else
          render json: { error: record.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy
        endpoint = params[:endpoint].to_s
        current_user.web_push_subscriptions.where(endpoint: endpoint).delete_all
        head :no_content
      end
    end
  end
end


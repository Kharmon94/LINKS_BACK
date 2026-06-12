# frozen_string_literal: true

module Api
  module V1
    module Admin
      class WebPushSubscriptionsController < BaseController
        before_action :set_subscription, only: :destroy

        def index
          authorize! :read, :admin_web_push
          result = paginated_scope(WebPushSubscription.includes(:user).order(created_at: :desc))
          render json: {
            webPushSubscriptions: result[:records].map { |s| subscription_json(s) },
            meta: result[:meta]
          }
        end

        def destroy
          authorize! :destroy, :admin_web_push
          @subscription.destroy!
          head :no_content
        end

        private

        def set_subscription
          @subscription = WebPushSubscription.find(params[:id])
        end

        def subscription_json(subscription)
          endpoint = subscription.endpoint.to_s
          {
            id: subscription.id.to_s,
            userId: subscription.user_id.to_s,
            userEmail: subscription.user.email,
            endpointPreview: endpoint.length > 48 ? "#{endpoint[0, 48]}…" : endpoint,
            createdAt: subscription.created_at&.iso8601
          }
        end

        def paginated_scope(scope)
          per_page = params[:per_page].to_i
          per_page = 50 if per_page <= 0
          per_page = [per_page, 200].min
          page = [params[:page].to_i, 1].max

          if params[:q].present?
            term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.downcase)}%"
            scope = scope.joins(:user).where(
              "lower(users.email) LIKE ? OR web_push_subscriptions.endpoint LIKE ?",
              term, term
            )
          end

          total = scope.count
          records = scope.offset((page - 1) * per_page).limit(per_page)
          {
            records: records,
            meta: { page: page, perPage: per_page, total: total, q: params[:q].presence }.compact
          }
        end
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    module Admin
      class TeamsController < BaseController
        def index
          authorize! :read, :admin_teams

          role_counts = User.group(:role).count
          stats = %w[owner admin member].index_with { |role| role_counts[role] || 0 }

          result = ::Admin::UserScope.call(
            q: params[:q],
            role: params[:role],
            page: params[:page],
            per_page: params[:per_page]
          )

          render json: {
            stats: stats,
            members: result[:users].map(&:as_json_for_admin),
            meta: result[:meta]
          }
        end
      end
    end
  end
end

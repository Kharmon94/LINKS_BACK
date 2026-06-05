# frozen_string_literal: true

module Api
  module V1
    module Admin
      class DashboardController < BaseController
        def show
          authorize! :read, :admin_dashboard
          render json: { stats: dashboard_stats }
        end

        private

        def dashboard_stats
          tier_counts = User.group(:subscription_tier).count
          role_counts = User.group(:role).count

          {
            usersCount: User.count,
            linksCount: Link.count,
            linksCreatedLast7Days: Link.where("created_at >= ?", 7.days.ago).count,
            usersByTier: User::TIER_LIMITS.keys.index_with { |tier| tier_counts[tier] || 0 },
            usersByRole: %w[owner admin member].index_with { |role| role_counts[role] || 0 },
            adminUsersCount: User.where(admin: true).count
          }
        end
      end
    end
  end
end

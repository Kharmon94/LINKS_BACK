# frozen_string_literal: true

module Api
  module V1
    module Admin
      class TeamsController < BaseController
        before_action :set_team, only: :show

        def index
          authorize! :read, :admin_teams
          result = team_scope
          render json: {
            teams: result[:teams].map { |team| team.as_json_for_admin },
            meta: result[:meta]
          }
        end

        def show
          authorize! :read, :admin_teams
          render json: { team: @team.as_json_for_admin(detail: true) }
        end

        private

        def set_team
          @team = HasPublicId.find_by_param!(
            Team.includes(
              team_memberships: :user,
              team_invitations: [],
              workspaces: []
            ),
            params[:id]
          )
        end

        def team_scope
          per_page = params[:per_page].to_i
          per_page = 50 if per_page <= 0
          per_page = [per_page, 200].min
          page = [params[:page].to_i, 1].max

          scope = Team.order(created_at: :desc)

          if params[:q].present?
            term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.downcase)}%"
            scope = scope.left_joins(team_memberships: :user).where(
              "lower(teams.name) LIKE ? OR lower(users.email) LIKE ?",
              term, term
            ).distinct
          end

          if params[:personal].present?
            personal = ActiveModel::Type::Boolean.new.cast(params[:personal])
            scope = scope.where(personal: personal)
          end

          total = scope.count
          teams = scope.offset((page - 1) * per_page).limit(per_page)

          {
            teams: teams,
            meta: {
              page: page,
              perPage: per_page,
              total: total,
              q: params[:q].presence
            }.compact
          }
        end
      end
    end
  end
end

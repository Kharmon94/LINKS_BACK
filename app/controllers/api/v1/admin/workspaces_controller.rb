# frozen_string_literal: true

module Api
  module V1
    module Admin
      class WorkspacesController < BaseController
        before_action :set_workspace, only: :destroy

        def index
          authorize! :read, :admin_workspaces
          result = paginated_scope(Workspace.includes(:team).order(created_at: :desc))
          render json: {
            workspaces: result[:records].map { |w| workspace_json(w) },
            meta: result[:meta]
          }
        end

        def destroy
          authorize! :destroy, :admin_workspaces
          @workspace.destroy!
          head :no_content
        end

        private

        def set_workspace
          @workspace = Workspace.find(params[:id])
        end

        def workspace_json(workspace)
          {
            id: workspace.id.to_s,
            name: workspace.name,
            teamId: workspace.team_id.to_s,
            teamName: workspace.team.name,
            linksCount: workspace.links.count,
            createdAt: workspace.created_at&.iso8601
          }
        end

        def paginated_scope(scope)
          per_page = params[:per_page].to_i
          per_page = 50 if per_page <= 0
          per_page = [per_page, 200].min
          page = [params[:page].to_i, 1].max

          if params[:q].present?
            term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.downcase)}%"
            scope = scope.joins(:team).where(
              "lower(workspaces.name) LIKE ? OR lower(teams.name) LIKE ?",
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

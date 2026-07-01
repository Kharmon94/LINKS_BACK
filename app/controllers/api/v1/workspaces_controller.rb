# frozen_string_literal: true

module Api
  module V1
    class WorkspacesController < BaseController
      before_action :require_workspaces_feature!
      before_action :set_workspace, only: %i[show update destroy add_member remove_member]

      def index
        workspaces = current_user.accessible_workspaces.includes(:workspace_memberships)
        render json: { workspaces: workspaces.map { |workspace| workspace.as_json_for_client(include_members: true) } }
      end

      def show
        authorize! :read, @workspace
        render json: { workspace: @workspace.as_json_for_client(include_members: true) }
      end

      def create
        team = current_user.primary_team
        return render json: { error: "Team not found" }, status: :not_found unless team

        workspace = team.workspaces.build(workspace_params)
        authorize! :create, workspace

        ActiveRecord::Base.transaction do
          workspace.save!
          team.team_memberships.find_each do |membership|
            workspace.workspace_memberships.find_or_create_by!(user_id: membership.user_id)
          end
        end

        render json: { workspace: workspace.as_json_for_client(include_members: true) }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      def update
        authorize! :update, @workspace
        if @workspace.update(workspace_params)
          render json: { workspace: @workspace.as_json_for_client(include_members: true) }
        else
          render json: { error: @workspace.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize! :destroy, @workspace
        if @workspace.team.workspaces.count <= 1
          return render json: { error: "Cannot delete the team's last workspace" }, status: :unprocessable_entity
        end

        if @workspace.id == current_user.active_workspace_id
          fallback = current_user.accessible_workspaces.where.not(id: @workspace.id).first
          current_user.update!(active_workspace: fallback)
        end
        @workspace.destroy!
        head :no_content
      end

      def add_member
        authorize! :update, @workspace
        user = HasPublicId.find_by_param!(User, params[:user_id])
        membership = current_user.primary_team.team_memberships.find_by!(user_id: user.id)
        @workspace.workspace_memberships.find_or_create_by!(user: membership.user)
        render json: { workspace: @workspace.reload.as_json_for_client(include_members: true) }
      end

      def remove_member
        authorize! :update, @workspace
        user = HasPublicId.find_by_param!(User, params[:user_id])
        membership = @workspace.workspace_memberships.find_by!(user_id: user.id)
        team_membership = current_user.primary_team.team_memberships.find_by(user_id: user.id)
        if team_membership&.role == "owner"
          return render json: { error: "Cannot remove the team owner from a workspace" }, status: :unprocessable_entity
        end

        membership.destroy!
        render json: { workspace: @workspace.reload.as_json_for_client(include_members: true) }
      end

      private

      def require_workspaces_feature!
        return if FeatureFlag.enabled?(:workspaces)

        render json: { error: "Workspaces feature is not enabled" }, status: :forbidden
      end

      def set_workspace
        @workspace = HasPublicId.find_by_param!(current_user.accessible_workspaces, params[:id])
      end

      def workspace_params
        params.require(:workspace).permit(:name, :description)
      rescue ActionController::ParameterMissing
        params.permit(:name, :description)
      end
    end
  end
end

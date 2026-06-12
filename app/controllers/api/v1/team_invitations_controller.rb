# frozen_string_literal: true

module Api
  module V1
    class TeamInvitationsController < ApplicationController
      before_action :authenticate_from_bearer!, only: [:accept]

      def show
        invitation = TeamInvitation.includes(:team).find_by(token: params[:token])
        unless invitation
          return render json: { error: "Invitation not found" }, status: :not_found
        end

        render json: { invitation: invitation.as_json_for_preview }
      end

      def accept
        invitation = TeamInvitation.includes(:team).find_by(token: params[:token])
        unless invitation&.pending?
          return render json: { error: "Invitation is invalid or expired" }, status: :unprocessable_entity
        end

        authorize! :accept, TeamInvitation

        if current_user.email.downcase != invitation.email.downcase
          return render json: { error: "This invitation was sent to a different email address" }, status: :forbidden
        end

        invitation.accept!(current_user)
        render json: { user: current_user.reload.as_json_for_client }
      end
    end
  end
end

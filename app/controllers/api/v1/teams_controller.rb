# frozen_string_literal: true

module Api
  module V1
    class TeamsController < BaseController
      before_action :require_workspaces_feature!
      before_action :set_team
      before_action :set_membership, only: %i[show_member update_member destroy_member member_clicks]

      def show
        authorize! :read, :team
        render json: {
          members: @team.team_memberships.includes(:user).map(&:as_json_for_client),
          invitations: @team.team_invitations.pending.map(&:as_json_for_client)
        }
      end

      def show_member
        authorize! :read, @membership
        render json: { member: member_detail_json(@membership) }
      end

      def member_clicks
        authorize! :read, @membership
        member_user = @membership.user
        events = ClickEvent.joins(:link)
                           .where(links: { user_id: member_user.id })
                           .order(clicked_at: :desc)
                           .limit(25)

        render json: {
          clicks: events.map do |event|
            {
              id: event.id.to_s,
              linkName: event.link.name.presence || "Untitled",
              shortUrl: event.link.as_json_for_client[:shortUrl],
              timestamp: event.clicked_at.iso8601,
              location: [event.city, event.country].compact.join(", ").presence || "Unknown"
            }
          end
        }
      end

      def create_invitation
        authorize! :create, TeamInvitation
        email = invitation_params[:email].to_s.strip.downcase

        if @team.team_memberships.joins(:user).exists?(users: { email: email })
          return render json: { error: "This email is already a team member" }, status: :unprocessable_entity
        end

        if @team.team_invitations.pending.exists?(email: email)
          return render json: { error: "A pending invitation already exists for this email" }, status: :unprocessable_entity
        end

        invitation = @team.team_invitations.build(
          email: email,
          role: invitation_params[:role].presence || "member",
          invited_by: current_user
        )

        if invitation.save
          TeamMailer.invitation(invitation).deliver_later
          render json: { invitation: invitation.as_json_for_client }, status: :created
        else
          render json: { error: invitation.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def update_member
        authorize! :update, @membership
        if @membership.user_id == current_user.id && membership_params[:role].present?
          return render json: { error: "You cannot change your own role" }, status: :unprocessable_entity
        end
        if @membership.role == "owner"
          return render json: { error: "Owner role cannot be modified" }, status: :unprocessable_entity
        end

        if @membership.update(membership_params)
          render json: { member: member_detail_json(@membership) }
        else
          render json: { error: @membership.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy_member
        authorize! :destroy, @membership
        if @membership.role == "owner"
          return render json: { error: "Owner cannot be removed" }, status: :unprocessable_entity
        end
        if @membership.user_id == current_user.id
          return render json: { error: "You cannot remove yourself" }, status: :unprocessable_entity
        end

        @membership.destroy!
        head :no_content
      end

      private

      def require_workspaces_feature!
        return if FeatureFlag.enabled?(:workspaces)

        render json: { error: "Workspaces feature is not enabled" }, status: :forbidden
      end

      def set_team
        @team = current_user.primary_team
        return if @team

        render json: { error: "Team not found" }, status: :not_found
      end

      def set_membership
        user = HasPublicId.find_by_param!(
          User.joins(:team_memberships).where(team_memberships: { team_id: @team.id }),
          params[:member_id]
        )
        @membership = @team.team_memberships.find_by!(user_id: user.id)
      end

      def invitation_params
        params.permit(:email, :role)
      end

      def membership_params
        params.permit(:role)
      end

      def member_detail_json(membership)
        user = membership.user
        workspace_names = user.workspaces.where(team_id: @team.id).pluck(:name)
        links_scope = user.links
        {
          id: user.public_id,
          name: user.name,
          email: user.email,
          role: membership.role,
          joinedAt: membership.created_at&.iso8601,
          stats: {
            linksCreated: links_scope.count,
            totalClicks: links_scope.sum(:clicks_count),
            campaigns: user.campaigns.count,
            workspaces: workspace_names
          }
        }
      end
    end
  end
end

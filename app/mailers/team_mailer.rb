# frozen_string_literal: true

class TeamMailer < ApplicationMailer
  def invitation(invitation)
    @invitation = invitation
    @team = invitation.team
    @inviter = invitation.invited_by
    @role = invitation.role.to_s.capitalize
    @expiry_days = invitation.expires_at ? [((invitation.expires_at - Time.current) / 1.day).ceil, 1].max : 7
    @accept_url = "#{frontend_app_url}/accept-invite/#{CGI.escape(invitation.token)}"
    mail to: invitation.email, subject: "You've been invited to join #{@team.name} on Links"
  end
end

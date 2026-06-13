# frozen_string_literal: true

class TeamMailer < ApplicationMailer
  def invitation(invitation)
    @invitation = invitation
    @team = invitation.team
    @accept_url = "#{frontend_app_url}/accept-invite/#{CGI.escape(invitation.token)}"
    mail to: invitation.email, subject: "You've been invited to join #{@team.name} on Links"
  end

  private

  def frontend_app_url
    ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").chomp("/")
  end
end

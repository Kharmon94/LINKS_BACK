# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamMailer, type: :mailer do
  let(:owner) do
    User.create!(
      email: "owner-mailer@example.com",
      password: "password123",
      name: "Owner",
      role: "owner"
    )
  end

  let(:team) { owner.primary_team }

  let(:invitation) do
    team.team_invitations.create!(
      email: "invitee@example.com",
      role: "member",
      invited_by: owner
    )
  end

  around do |example|
    previous = ENV["FRONTEND_ORIGIN"]
    ENV["FRONTEND_ORIGIN"] = "https://app.example.com"
    example.run
  ensure
    if previous.nil?
      ENV.delete("FRONTEND_ORIGIN")
    else
      ENV["FRONTEND_ORIGIN"] = previous
    end
  end

  def html_body(mail)
    mail.html_part&.body&.to_s || mail.body.to_s
  end

  def text_body(mail)
    mail.text_part&.body&.to_s || mail.body.to_s
  end

  describe "#invitation" do
    it "sends branded HTML and text with accept URL" do
      mail = described_class.invitation(invitation)

      expect(mail.to).to eq(["invitee@example.com"])
      expect(mail.subject).to include(team.name)
      expect(mail.subject).to include("Links")
      expect(text_body(mail)).to include("https://app.example.com/accept-invite/")
      expect(text_body(mail)).to include(invitation.token)
      expect(html_body(mail)).to include("You've Been Invited!")
      expect(html_body(mail)).to include(team.name)
      expect(html_body(mail)).to include("Accept Invitation")
      expect(html_body(mail)).to include(invitation.token)
      expect(html_body(mail)).to include("BlackCollar")
      expect(html_body(mail)).to include("The Links Team")
    end
  end
end

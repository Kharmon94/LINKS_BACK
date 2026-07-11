# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  let(:user) do
    User.create!(
      email: "mailer-alerts@example.com",
      password: "password123",
      name: "Mailer",
      role: "owner"
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

  describe "#link_milestone" do
    it "sends text mail with deep link" do
      link = Link.create!(
        user: user,
        destination_url: "https://example.com",
        name: "Launch",
        short_code: "mail01"
      )

      mail = described_class.link_milestone(user, link, clicks: 42)

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to include("Launch")
      expect(mail.body.encoded).to include('Your link "Launch" has 42 clicks')
      expect(mail.body.encoded).to include("https://app.example.com/links/#{link.public_id}")
    end
  end

  describe "#campaign_milestone" do
    it "sends text mail with deep link" do
      campaign = Campaign.create!(user: user, name: "Spring")

      mail = described_class.campaign_milestone(user, campaign, clicks: 10)

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to include("Spring")
      expect(mail.body.encoded).to include('Your campaign "Spring" has 10 clicks')
      expect(mail.body.encoded).to include("https://app.example.com/campaigns/#{campaign.public_id}")
    end
  end
end

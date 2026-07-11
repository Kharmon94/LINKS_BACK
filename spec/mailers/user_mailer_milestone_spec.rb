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
    previous_origin = ENV["FRONTEND_ORIGIN"]
    previous_logo = ENV["EMAIL_LOGO_URL"]
    ENV["FRONTEND_ORIGIN"] = "https://app.example.com"
    ENV["EMAIL_LOGO_URL"] = "https://cdn.example.com/logo.png"
    example.run
  ensure
    if previous_origin.nil?
      ENV.delete("FRONTEND_ORIGIN")
    else
      ENV["FRONTEND_ORIGIN"] = previous_origin
    end
    if previous_logo.nil?
      ENV.delete("EMAIL_LOGO_URL")
    else
      ENV["EMAIL_LOGO_URL"] = previous_logo
    end
  end

  def html_body(mail)
    mail.html_part&.body&.to_s || mail.body.to_s
  end

  def text_body(mail)
    mail.text_part&.body&.to_s || mail.body.to_s
  end

  describe "#magic_link" do
    it "sends branded HTML and text with verify CTA" do
      user.assign_magic_link!
      mail = described_class.magic_link(user)

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq("Sign in to Links")
      expect(text_body(mail)).to include(user.magic_link_token)
      expect(html_body(mail)).to include("Sign in to Links")
      expect(html_body(mail)).to include("/auth/verify?token=")
      expect(html_body(mail)).to include("https://cdn.example.com/logo.png")
      expect(html_body(mail)).to include("BlackCollar")
    end
  end

  describe "#link_created" do
    it "sends branded HTML and text with short URL" do
      link = Link.create!(
        user: user,
        destination_url: "https://example.com",
        name: "Launch",
        short_code: "mail01"
      )

      mail = described_class.link_created(user, link)

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq("Your link is ready!")
      expect(text_body(mail)).to include("Your short link is live:")
      expect(html_body(mail)).to include("Your link is ready!")
      expect(html_body(mail)).to include(link.short_code)
      expect(html_body(mail)).to include("https://app.example.com")
      expect(html_body(mail)).to include("BlackCollar")
    end
  end

  describe "#link_milestone" do
    it "sends HTML and text with deep link" do
      link = Link.create!(
        user: user,
        destination_url: "https://example.com",
        name: "Launch",
        short_code: "mail01"
      )

      mail = described_class.link_milestone(user, link, clicks: 42)

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to include("Launch")
      expect(text_body(mail)).to include('Your link "Launch" has 42 clicks')
      expect(text_body(mail)).to include("https://app.example.com/links/#{link.public_id}")
      expect(html_body(mail)).to include("Milestone Reached!")
      expect(html_body(mail)).to include("https://app.example.com/links/#{link.public_id}")
      expect(html_body(mail)).to include("View Full Analytics")
      expect(html_body(mail)).to include("BlackCollar")
    end
  end

  describe "#campaign_milestone" do
    it "sends HTML and text with deep link" do
      campaign = Campaign.create!(user: user, name: "Spring")

      mail = described_class.campaign_milestone(user, campaign, clicks: 10)

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to include("Spring")
      expect(text_body(mail)).to include('Your campaign "Spring" has 10 clicks')
      expect(text_body(mail)).to include("https://app.example.com/campaigns/#{campaign.public_id}")
      expect(html_body(mail)).to include("Campaign Milestone")
      expect(html_body(mail)).to include("Spring")
      expect(html_body(mail)).to include("https://app.example.com/campaigns/#{campaign.public_id}")
      expect(html_body(mail)).to include("BlackCollar")
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContactMailer, type: :mailer do
  around do |example|
    previous_inbox = ENV["CONTACT_INBOX_EMAIL"]
    previous_origin = ENV["FRONTEND_ORIGIN"]
    ENV["CONTACT_INBOX_EMAIL"] = "ops@example.com"
    ENV["FRONTEND_ORIGIN"] = "https://app.example.com"
    example.run
  ensure
    if previous_inbox.nil?
      ENV.delete("CONTACT_INBOX_EMAIL")
    else
      ENV["CONTACT_INBOX_EMAIL"] = previous_inbox
    end
    if previous_origin.nil?
      ENV.delete("FRONTEND_ORIGIN")
    else
      ENV["FRONTEND_ORIGIN"] = previous_origin
    end
  end

  def html_body(mail)
    mail.html_part&.body&.to_s || mail.body.to_s
  end

  def text_body(mail)
    mail.text_part&.body&.to_s || mail.body.to_s
  end

  describe "#inbound" do
    it "sends branded HTML and text to the ops inbox" do
      mail = described_class.inbound(
        name: "Pat",
        email: "pat@example.com",
        message: "Hello from the contact form"
      )

      expect(mail.to).to eq(["ops@example.com"])
      expect(mail.reply_to).to eq(["pat@example.com"])
      expect(mail.subject).to include("pat@example.com")
      expect(text_body(mail)).to include("Hello from the contact form")
      expect(html_body(mail)).to include("Contact form message")
      expect(html_body(mail)).to include("Hello from the contact form")
      expect(html_body(mail)).to include("BlackCollar")
    end
  end
end

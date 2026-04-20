# frozen_string_literal: true

class ContactMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM", "noreply@example.com")

  def inbound(name:, email:, message:)
    @name = name
    @email = email
    @message = message
    to_addr = ENV.fetch("CONTACT_INBOX_EMAIL", "support@example.com")
    mail to: to_addr, reply_to: email, subject: "Contact form: #{email}"
  end
end

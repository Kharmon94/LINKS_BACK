# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "info@updates.blackcollar.io")
  layout "mailer"
  helper MailerHelper

  private

  def frontend_app_url
    ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").chomp("/")
  end

  def email_logo_url
    ENV["EMAIL_LOGO_URL"].presence || "#{frontend_app_url}/icons/icon-512.png"
  end
end

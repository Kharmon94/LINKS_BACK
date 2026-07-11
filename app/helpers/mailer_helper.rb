# frozen_string_literal: true

module MailerHelper
  PRODUCT_NAME = "Links"
  PARENT_BRAND = "BlackCollar"

  def frontend_app_url
    ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").chomp("/")
  end

  def email_logo_url
    ENV["EMAIL_LOGO_URL"].presence || "#{frontend_app_url}/icons/icon-512.png"
  end

  def email_dashboard_url
    frontend_app_url
  end

  def email_help_url
    "#{frontend_app_url}/help"
  end

  def email_privacy_url
    "#{frontend_app_url}/privacy"
  end

  def email_preferences_url
    "#{frontend_app_url}/settings"
  end
end

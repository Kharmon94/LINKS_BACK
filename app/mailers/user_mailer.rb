# frozen_string_literal: true

class UserMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM", "noreply@example.com")

  def magic_link(user)
    @user = user
    @verify_url = "#{frontend_app_url}/auth/verify?token=#{CGI.escape(user.magic_link_token)}"
    mail to: user.email, subject: "Sign in to Links"
  end

  def link_created(user, link)
    @user = user
    @link = link
    @short_url = "https://#{link.short_link_host}/#{link.short_code}"
    mail to: user.email, subject: "Your link is ready!"
  end

  private

  def frontend_app_url
    ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").chomp("/")
  end
end

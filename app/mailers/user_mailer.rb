# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def magic_link(user)
    @user = user
    @verify_url = "#{frontend_app_url}/auth/verify?token=#{CGI.escape(user.magic_link_token)}"
    mail to: user.email, subject: "Sign in to Links"
  end

  def link_created(user, link)
    @user = user
    @link = link
    @short_url = "https://#{link.short_link_host}/#{link.short_code}"
    @dashboard_url = frontend_app_url
    mail to: user.email, subject: "Your link is ready!"
  end

  def link_milestone(user, link, clicks:)
    @user = user
    @link = link
    @clicks = clicks
    @link_url = "#{frontend_app_url}/links/#{link.public_id}"
    @short_url = "https://#{link.short_link_host}/#{link.short_code}"
    mail to: user.email, subject: "Link milestone: #{link.name.presence || 'Untitled'}"
  end

  def campaign_milestone(user, campaign, clicks:)
    @user = user
    @campaign = campaign
    @clicks = clicks
    @campaign_url = "#{frontend_app_url}/campaigns/#{campaign.public_id}"
    mail to: user.email, subject: "Campaign milestone: #{campaign.name}"
  end
end

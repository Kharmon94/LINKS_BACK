# frozen_string_literal: true

module Api
  module V1
    class PublicLinksController < ApplicationController
      def create_with_account
        url = nested_or(:url, :destination_url)
        name = nested_or(:name, :title).presence || "My Experience"
        user_name = nested_or(:user_name, :name)
        email = nested_or(:email)

        unless UrlValidator.safe_http_url?(url)
          return render json: { error: "Invalid URL format" }, status: :unprocessable_entity
        end
        if email.blank? || user_name.blank?
          return render json: { error: "Name and email are required" }, status: :unprocessable_entity
        end

        email = email.to_s.strip.downcase

        user = User.find_by("lower(email) = ?", email) || User.new(email: email)
        user.name = user_name if user.name.blank?
        user.password ||= Devise.friendly_token(32)
        user.subscription_tier ||= "free"
        user.role ||= "owner"

        if user.persisted? && user.at_link_limit?
          return render json: {
            error: "You've reached your free tier limit. Upgrade to create more links.",
            upgrade_url: "/pricing"
          }, status: :forbidden
        end

        ActiveRecord::Base.transaction do
          user.save!
          link = user.links.build(destination_url: url, name: name)
          user.assign_default_workspace!(link)
          link.save!
          user.assign_magic_link!
          UserMailer.link_created(user, link).deliver_later
          UserMailer.magic_link(user).deliver_later
        end

        user.reload
        link = user.links.order(created_at: :desc).first

        render json: {
          short_url: "https://#{link.short_link_host}/#{link.short_code}",
          short_code: link.short_code,
          user: user.as_json_for_client,
          token: JwtService.encode(user)
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      private

      def nested_or(*keys)
        keys.each do |key|
          v = params[key]
          return v if v.present?
          nested = params[:resource] || params[:link] || params[:user]
          return nested[key] if nested.is_a?(ActionController::Parameters) && nested[key].present?
        end
        nil
      end
    end
  end
end

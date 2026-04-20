# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate_from_bearer!, only: %i[session logout]

      def magic_link
        email = param_email
        return render json: { error: "Email is required" }, status: :unprocessable_entity if email.blank?

        user = User.find_by("lower(email) = ?", email.downcase)
        unless user
          return render json: { error: "No account found with that email. Create a link first!" },
                        status: :not_found
        end

        user.assign_magic_link!
        UserMailer.magic_link(user).deliver_later

        render json: { message: "Magic link sent! Check your email." }
      end

      def verify
        token = params[:token].presence || params.dig(:auth, :token)
        return render json: { error: "Token is required" }, status: :unprocessable_entity if token.blank?

        user = User.find_by(magic_link_token: token)
        unless user&.magic_link_valid?(token)
          return render json: { error: "Invalid or expired token" }, status: :unauthorized
        end

        user.clear_magic_link!
        render json: { user: user.as_json_for_client, token: JwtService.encode(user) }
      end

      def session
        render json: { user: current_user.as_json_for_client }
      end

      def logout
        render json: { message: "Logged out successfully" }
      end

      private

      def param_email
        params[:email].presence || params.dig(:auth, :email)
      end
    end
  end
end

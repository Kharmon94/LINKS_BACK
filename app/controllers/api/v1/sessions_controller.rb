# frozen_string_literal: true

module Api
  module V1
    class SessionsController < ApplicationController
      before_action :authenticate_from_bearer!, only: [:me]

      def create
        email = params[:email].to_s.strip.downcase
        password = params[:password].to_s
        user = User.find_for_database_authentication(email: email)
        if user&.valid_password?(password)
          render json: { user: user.as_json_for_client, token: JwtService.encode(user) }
        else
          render json: { error: "Incorrect email or password" }, status: :unauthorized
        end
      end

      def me
        render json: { user: current_user.as_json_for_client }
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class RegistrationsController < ApplicationController
      def create
        email = params[:email].to_s.strip.downcase
        password = params[:password].to_s
        name = params[:name].to_s.strip.presence || email.split("@").first

        user = User.new(email: email, password: password, name: name, subscription_tier: "free", role: "owner")
        if user.save
          render json: { user: user.as_json_for_client, token: JwtService.encode(user) }, status: :created
        else
          render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end
    end
  end
end

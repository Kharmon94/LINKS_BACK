# frozen_string_literal: true

module Api
  module V1
    class ContactsController < ApplicationController
      def create
        email = params[:email].to_s.strip
        message = params[:message].to_s.strip
        name = params[:name].to_s.strip
        if email.blank? || message.blank?
          return render json: { error: "Email and message are required" }, status: :unprocessable_entity
        end

        ContactMailer.inbound(name:, email:, message:).deliver_later
        render json: { message: "Thanks — we'll get back to you shortly." }, status: :created
      end
    end
  end
end

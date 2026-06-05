# frozen_string_literal: true

class ApplicationController < ActionController::API
  include CanCan::ControllerAdditions

  rescue_from CanCan::AccessDenied do |exception|
    render json: { error: "Access denied", message: exception.message }, status: :forbidden
  end

  private

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  def authenticate_from_bearer!
    token = bearer_token
    @current_user = JwtService.user_from_token(token) if token.present?
    render json: { error: "Not authenticated" }, status: :unauthorized unless @current_user
  end

  def authenticate_from_bearer_optional!
    token = bearer_token
    @current_user = JwtService.user_from_token(token) if token.present?
  end

  def current_user
    @current_user
  end

  def bearer_token
    request.headers["Authorization"].to_s[/Bearer (.+)/, 1]
  end

  def frontend_origin
    ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").chomp("/")
  end
end

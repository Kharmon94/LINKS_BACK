# frozen_string_literal: true
# this is a test comment delete after testing
module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token, raise: false

    def google_oauth2
      auth = request.env["omniauth.auth"]
      unless auth
        redirect_to "#{frontend_origin}/auth?error=oauth_failed", allow_other_host: true
        return
      end

      user = User.from_google_omniauth(auth)
      token = JwtService.encode(user)
      redirect_to "#{frontend_origin}/auth/oauth-complete#token=#{CGI.escape(token)}", allow_other_host: true
    rescue StandardError => e
      Rails.logger.error("[Google OAuth] #{e.class}: #{e.message}")
      redirect_to "#{frontend_origin}/auth?error=oauth_failed", allow_other_host: true
    end

    def failure
      redirect_to "#{frontend_origin}/auth?error=#{CGI.escape(params[:message].to_s)}", allow_other_host: true
    end

    private

    def frontend_origin
      ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173").chomp("/")
    end
  end
end

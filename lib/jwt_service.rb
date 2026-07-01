# frozen_string_literal: true

class JwtService
  class << self
    def encode(user)
      payload = {
        sub: user.id,
        exp: session_expiry.from_now.to_i,
        iat: Time.now.to_i
      }
      JWT.encode(payload, secret, "HS256")
    end

    def decode(token)
      JWT.decode(token, secret, true, { algorithm: "HS256" }).first
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end

    def user_from_token(token)
      payload = decode(token)
      return nil unless payload

      User.find_by(id: payload["sub"])
    end

    def session_expiry
      days = ENV.fetch("JWT_SESSION_DAYS", "30").to_i
      days.positive? ? days.days : 30.days
    end

    private

    def secret
      ENV.fetch("DEVISE_JWT_SECRET_KEY") do
        Rails.application.credentials.secret_key_base
      end
    end
  end
end

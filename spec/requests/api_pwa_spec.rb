# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PWA install confirmation", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) do
    User.create!(
      email: "pwa@example.com",
      password: "password123",
      name: "PWA User",
      subscription_tier: "free",
      role: "owner"
    )
  end

  let(:token) { JwtService.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/v1/pwa/confirm_install" do
    it "sets pwa_installed_at on first call" do
      expect(user.pwa_installed_at).to be_nil

      post "/api/v1/pwa/confirm_install", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["user"]["pwaInstalledAt"]).to be_present
      expect(user.reload.pwa_installed_at).to be_present
    end

    it "is idempotent on repeat calls" do
      post "/api/v1/pwa/confirm_install", headers: headers, as: :json
      first_timestamp = user.reload.pwa_installed_at

      travel_to 1.hour.from_now do
        post "/api/v1/pwa/confirm_install", headers: headers, as: :json
      end

      expect(response).to have_http_status(:ok)
      expect(user.reload.pwa_installed_at).to eq(first_timestamp)
    end

    it "requires authentication" do
      post "/api/v1/pwa/confirm_install", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

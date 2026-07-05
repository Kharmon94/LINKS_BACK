# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin user feature flags API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", name: "Admin", admin: true, role: "owner") }
  let(:user) { User.create!(email: "u@example.com", password: "password123", name: "U", role: "owner") }

  before do
    FeatureFlag.find_by!(key: "campaigns").update!(enabled: false)
  end

  describe "GET /api/v1/admin/users/:user_id/feature_flags" do
    it "lists all flags with override state" do
      user.feature_flag_overrides.create!(feature_flag_key: "campaigns", enabled: true)

      get "/api/v1/admin/users/#{user.id}/feature_flags", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      flags = response.parsed_body["userFeatureFlags"]
      expect(flags).to be_an(Array)
      campaigns = flags.find { |f| f["key"] == "campaigns" }
      expect(campaigns).to include(
        "globalEnabled" => false,
        "override" => true,
        "effectiveEnabled" => true
      )
    end

    it "forbids non-admin" do
      get "/api/v1/admin/users/#{user.id}/feature_flags", headers: auth_headers(user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/admin/users/:user_id/feature_flags/:key" do
    it "sets an override" do
      patch "/api/v1/admin/users/#{user.id}/feature_flags/campaigns",
            params: { enabled: true },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["userFeatureFlag"]
      expect(body["override"]).to be true
      expect(body["effectiveEnabled"]).to be true
      expect(FeatureFlag.enabled_for?(user.reload, :campaigns)).to be true
    end

    it "clears an override when enabled is null" do
      user.feature_flag_overrides.create!(feature_flag_key: "campaigns", enabled: true)

      patch "/api/v1/admin/users/#{user.id}/feature_flags/campaigns",
            params: { enabled: nil },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["userFeatureFlag"]
      expect(body["override"]).to be_nil
      expect(body["effectiveEnabled"]).to be false
      expect(user.feature_flag_overrides.count).to eq(0)
    end

    it "forbids non-admin" do
      patch "/api/v1/admin/users/#{user.id}/feature_flags/campaigns",
            params: { enabled: true },
            headers: auth_headers(user),
            as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end

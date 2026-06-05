# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin feature flags API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", name: "Admin", admin: true, role: "owner") }
  let(:user) { User.create!(email: "u@example.com", password: "password123", name: "U", role: "owner") }

  it "lists flags" do
    get "/api/v1/admin/feature_flags", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["featureFlags"]).to be_an(Array)
    expect(response.parsed_body["featureFlags"].first).to include("key", "enabled", "category")
  end

  it "toggles flag" do
    patch "/api/v1/admin/feature_flags/campaigns",
          params: { enabled: true },
          headers: auth_headers(admin),
          as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["featureFlag"]["enabled"]).to be true
    expect(FeatureFlag.enabled?(:campaigns)).to be true
  end

  it "affects presenter permissions" do
    patch "/api/v1/admin/feature_flags/campaigns",
          params: { enabled: true },
          headers: auth_headers(admin),
          as: :json
    json = user.reload.as_json_for_client
    expect(json.dig(:permissions, :campaigns, :read)).to be true
  end

  it "forbids non-admin" do
    get "/api/v1/admin/feature_flags", headers: auth_headers(user)
    expect(response).to have_http_status(:forbidden)
  end
end

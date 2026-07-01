# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin health API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", name: "Admin", admin: true, role: "owner") }
  let(:user) { User.create!(email: "u@example.com", password: "password123", name: "U", role: "member") }

  it "returns health payload for admin" do
    get "/api/v1/admin/health", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    health = response.parsed_body["health"]
    expect(health["database"]["ok"]).to eq(true)
    expect(health["stripe"]).to include("configured", "mode", "testConfigured", "liveConfigured")
    expect(health).to include("version", "migrationVersion")
    expect(health["mail"]).to include(
      "resendConfigured" => false,
      "mailerFrom" => be_present,
      "queueAdapter" => "test"
    )
  end

  it "forbids non-admin" do
    get "/api/v1/admin/health", headers: auth_headers(user)
    expect(response).to have_http_status(:forbidden)
  end
end

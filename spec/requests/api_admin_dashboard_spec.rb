# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin dashboard API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", name: "Admin", admin: true, role: "owner") }
  let(:user) { User.create!(email: "u@example.com", password: "password123", name: "U", role: "owner") }

  it "returns stats for platform admin" do
    admin
    user
    Link.create!(user: user, destination_url: "https://example.com", name: "L")

    get "/api/v1/admin/dashboard", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    stats = response.parsed_body["stats"]
    expect(stats["usersCount"]).to be >= 2
    expect(stats["linksCount"]).to eq(1)
    expect(stats).to include("usersByTier", "usersByRole", "adminUsersCount")
  end

  it "forbids non-admin" do
    get "/api/v1/admin/dashboard", headers: auth_headers(user)
    expect(response).to have_http_status(:forbidden)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin teams API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", name: "Admin", admin: true, role: "owner") }
  let(:user) { User.create!(email: "u@example.com", password: "password123", name: "U", role: "member") }

  before do
    admin
    user
  end

  it "returns role stats and members" do
    get "/api/v1/admin/teams", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["stats"]).to include("owner", "admin", "member")
    expect(body["members"]).to be_an(Array)
    expect(body["meta"]).to include("page", "total")
  end

  it "filters by role" do
    get "/api/v1/admin/teams", params: { role: "member" }, headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    emails = response.parsed_body["members"].map { |m| m["email"] }
    expect(emails).to include(user.email)
  end

  it "forbids non-admin" do
    get "/api/v1/admin/teams", headers: auth_headers(user)
    expect(response).to have_http_status(:forbidden)
  end
end

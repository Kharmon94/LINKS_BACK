# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin users", type: :request do
  let!(:admin) do
    User.create!(
      email: "admin@example.com",
      password: "password123",
      name: "Admin",
      admin: true,
      subscription_tier: "enterprise",
      role: "owner"
    )
  end

  let!(:member) do
    User.create!(
      email: "mem@example.com",
      password: "password123",
      name: "Mem",
      admin: false,
      subscription_tier: "free",
      role: "owner"
    )
  end

  it "forbids non-admin" do
    get "/api/v1/admin/users", headers: auth_headers(member)
    expect(response).to have_http_status(:forbidden)
  end

  it "lists users for admin with pagination meta" do
    get "/api/v1/admin/users", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["meta"]["total"]).to be >= 2
    expect(body["users"].size).to be >= 2
    expect(body["meta"]).to include("page", "perPage", "total")
    expect(body["users"].first).to include("linksCount", "createdAt")
  end

  it "searches users by email" do
    get "/api/v1/admin/users", params: { q: "mem@" }, headers: auth_headers(admin)
    emails = response.parsed_body["users"].map { |u| u["email"] }
    expect(emails).to include(member.email)
  end

  it "shows user with recent links" do
    Link.create!(user: member, destination_url: "https://example.com", name: "L")
    get "/api/v1/admin/users/#{member.id}", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    user_json = response.parsed_body["user"]
    expect(user_json["recentLinks"]).to be_an(Array)
    expect(user_json["recentLinks"].first).to include("shortCode", "shortUrl")
  end

  it "updates admin flag and role" do
    patch "/api/v1/admin/users/#{member.id}",
          params: { admin: true, role: "admin" },
          headers: auth_headers(admin),
          as: :json
    expect(response).to have_http_status(:ok)
    member.reload
    expect(member.admin).to be true
    expect(member.role).to eq("admin")
  end
end

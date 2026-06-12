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

  it "includes team info in admin user json" do
    get "/api/v1/admin/users/#{member.id}", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    user_json = response.parsed_body["user"]
    expect(user_json).to include("teamId", "teamName", "membershipRole")
    expect(user_json["teamId"]).to eq(member.primary_team.id.to_s)
  end

  it "updates subscription tier" do
    patch "/api/v1/admin/users/#{member.id}",
          params: { subscription_tier: "growth" },
          headers: auth_headers(admin),
          as: :json
    expect(response).to have_http_status(:ok)
    expect(member.reload.subscription_tier).to eq("growth")
    expect(response.parsed_body["user"]["subscriptionTier"]).to eq("growth")
  end

  it "rejects invalid subscription tier" do
    patch "/api/v1/admin/users/#{member.id}",
          params: { subscription_tier: "invalid" },
          headers: auth_headers(admin),
          as: :json
    expect(response).to have_http_status(:ok)
    expect(member.reload.subscription_tier).to eq("free")
  end

  it "syncs personal team membership when role changes" do
    membership = member.primary_team_membership
    expect(membership.role).to eq("owner")

    patch "/api/v1/admin/users/#{member.id}",
          params: { role: "member" },
          headers: auth_headers(admin),
          as: :json
    expect(response).to have_http_status(:ok)
    member.reload
    membership.reload
    expect(member.role).to eq("member")
    expect(membership.role).to eq("member")
    expect(response.parsed_body["user"]["membershipRole"]).to eq("member")
  end
end

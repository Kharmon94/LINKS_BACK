# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin users", type: :request do
  let(:admin) do
    User.create!(
      email: "admin@example.com",
      password: "password123",
      name: "Admin",
      admin: true,
      subscription_tier: "enterprise",
      role: "owner"
    )
  end

  let(:member) do
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
    get "/api/v1/admin/users", headers: { "Authorization" => "Bearer #{JwtService.encode(member)}" }
    expect(response).to have_http_status(:forbidden)
  end

  it "lists users for admin" do
    admin
    member
    get "/api/v1/admin/users", headers: { "Authorization" => "Bearer #{JwtService.encode(admin)}" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["users"].size).to be >= 2
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin teams API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", name: "Admin", admin: true, role: "owner") }
  let(:user) { User.create!(email: "u@example.com", password: "password123", name: "U", role: "member") }

  before do
    admin
    user
  end

  it "returns paginated Team entities" do
    team = user.primary_team
    get "/api/v1/admin/teams", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["teams"]).to be_an(Array)
    expect(body["teams"].first).to include("id", "name", "memberCount", "workspaceCount")
    expect(body["teams"].map { |t| t["id"] }).to include(team.id.to_s)
    expect(body["meta"]).to include("page", "total")
  end

  it "shows team detail with members" do
    team = user.primary_team
    get "/api/v1/admin/teams/#{team.id}", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    team_json = response.parsed_body["team"]
    expect(team_json["members"]).to be_an(Array)
    expect(team_json["members"].first["email"]).to eq(user.email)
  end

  it "forbids non-admin" do
    get "/api/v1/admin/teams", headers: auth_headers(user)
    expect(response).to have_http_status(:forbidden)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin links API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", name: "Admin", admin: true, role: "owner") }
  let(:user) { User.create!(email: "u@example.com", password: "password123", name: "U", role: "owner") }
  let!(:link) { Link.create!(user: user, destination_url: "https://example.com", name: "Test", short_code: "abc123") }

  it "lists links for admin" do
    get "/api/v1/admin/links", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["links"].first["shortCode"]).to eq("abc123")
    expect(body["links"].first["userEmail"]).to eq(user.email)
    expect(body["meta"]).to include("page", "perPage", "total")
  end

  it "shows link detail" do
    get "/api/v1/admin/links/#{link.id}", headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["link"]["id"]).to eq(link.id.to_s)
  end

  it "destroys link" do
    expect do
      delete "/api/v1/admin/links/#{link.id}", headers: auth_headers(admin)
    end.to change(Link, :count).by(-1)
    expect(response).to have_http_status(:no_content)
  end

  it "forbids non-admin" do
    get "/api/v1/admin/links", headers: auth_headers(user)
    expect(response).to have_http_status(:forbidden)
  end
end

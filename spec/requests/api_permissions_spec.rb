# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Permissions JSON contract", type: :request do
  let(:user) { User.create!(email: "u@example.com", password: "password123", name: "U", role: "owner", subscription_tier: "free") }

  it "includes permissions and limits on session" do
    get "/api/auth/session", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body["user"]
    expect(body["permissions"]).to include("platformAdmin", "links", "campaigns")
    expect(body["limits"]).to include("links", "campaigns")
    expect(body["permissions"]["links"]).to include("read", "create", "update", "destroy")
  end

  it "includes permissions on sign in" do
    post "/api/v1/auth/sign_in",
         params: { email: user.email, password: "password123" },
         as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["user"]["permissions"]).to be_present
    expect(response.parsed_body["user"]["limits"]["links"]["max"]).to eq(1)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Auth", type: :request do
  let!(:user) do
    User.create!(
      email: "member@example.com",
      password: "password123",
      name: "Member",
      subscription_tier: "free",
      role: "owner"
    )
  end

  it "rejects magic link for unknown email" do
    post "/api/auth/magic-link", params: { email: "nope@example.com" }, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "sends magic link for known user" do
    expect do
      post "/api/auth/magic-link", params: { email: user.email }, as: :json
    end.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    expect(response).to have_http_status(:ok)
  end

  it "verifies magic link and returns jwt" do
    user.assign_magic_link!
    post "/api/auth/verify", params: { token: user.magic_link_token }, as: :json
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["token"]).to be_present
    expect(body["user"]["email"]).to eq(user.email)
  end

  it "returns session with bearer token" do
    token = JwtService.encode(user)
    get "/api/auth/session", headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["user"]["email"]).to eq(user.email)
  end

  it "signs in with email and password" do
    post "/api/v1/auth/sign_in", params: { email: user.email, password: "password123" }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["token"]).to be_present
  end

  it "returns 401 for wrong password" do
    post "/api/v1/auth/sign_in", params: { email: user.email, password: "wrong" }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "signs in with different email casing" do
    post "/api/v1/auth/sign_in", params: { email: "MEMBER@example.com", password: "password123" }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["token"]).to be_present
  end

  it "allows GET to start Google OAuth (passthru)" do
    get "/users/auth/google_oauth2"
    expect(response.status).to be_between(300, 399)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Auth", type: :request do
  let!(:user) do
    User.create!(
      email: "member@example.com",
      password: "password123",
      name: "Member",
      subscription_tier: "free",
      role: "owner",
      password_set_at: Time.current
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

  it "validates magic link token and requires password for returning users" do
    user.assign_magic_link!
    post "/api/auth/verify", params: { token: user.magic_link_token }, as: :json
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["requiresPassword"]).to eq(true)
    expect(body["email"]).to eq(user.email)
    expect(body["mode"]).to eq("sign_in")
    expect(body["token"]).to be_nil
    expect(user.reload.magic_link_token).to be_present
  end

  it "signs in returning user with correct existing password without changing it" do
    user.assign_magic_link!
    token = user.magic_link_token
    post "/api/auth/verify", params: { token: token, password: "password123" }, as: :json
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["token"]).to be_present
    expect(body["user"]["email"]).to eq(user.email)
    expect(user.reload.magic_link_token).to be_nil
    expect(user.valid_password?("password123")).to be(true)
  end

  it "returns 401 for returning user with wrong password" do
    user.assign_magic_link!
    post "/api/auth/verify",
         params: { token: user.magic_link_token, password: "wrongpassword" },
         as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["error"]).to eq("Incorrect password")
    expect(user.reload.magic_link_token).to be_present
  end

  it "requires set_password mode for users without password_set_at" do
    new_user = User.create!(
      email: "new@example.com",
      password: Devise.friendly_token(32),
      name: "New User",
      subscription_tier: "free",
      role: "owner",
      password_set_at: nil
    )
    new_user.assign_magic_link!
    post "/api/auth/verify", params: { token: new_user.magic_link_token }, as: :json
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["requiresPassword"]).to eq(true)
    expect(body["mode"]).to eq("set_password")
  end

  it "completes magic link with password and returns jwt for first-time password set" do
    new_user = User.create!(
      email: "firsttime@example.com",
      password: Devise.friendly_token(32),
      name: "First Timer",
      subscription_tier: "free",
      role: "owner",
      password_set_at: nil
    )
    new_user.assign_magic_link!
    token = new_user.magic_link_token
    post "/api/auth/verify",
         params: { token: token, password: "newpassword1", password_confirmation: "newpassword1" },
         as: :json
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["token"]).to be_present
    expect(body["user"]["email"]).to eq(new_user.email)
    expect(new_user.reload.magic_link_token).to be_nil
    expect(new_user.valid_password?("newpassword1")).to be(true)
    expect(new_user.password_set_at).to be_present
  end

  it "returns set_password mode for users created via public link path" do
    post "/api/links/create-with-account",
         params: {
           email: "public@example.com",
           user_name: "Public User",
           url: "https://example.com/page",
           name: "My Link"
         },
         as: :json
    expect(response).to have_http_status(:ok)

    created_user = User.find_by(email: "public@example.com")
    expect(created_user.password_set_at).to be_nil

    created_user.assign_magic_link!
    post "/api/auth/verify", params: { token: created_user.magic_link_token }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["mode"]).to eq("set_password")
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

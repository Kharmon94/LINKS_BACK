# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Account", type: :request do
  let!(:user) do
    User.create!(
      email: "account@example.com",
      password: "password123",
      name: "Account User",
      subscription_tier: "free",
      role: "owner",
      password_set_at: Time.current
    )
  end

  describe "PATCH /api/v1/account" do
    it "updates name" do
      patch "/api/v1/account",
            params: { name: "Updated Name" },
            headers: auth_headers(user),
            as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]["name"]).to eq("Updated Name")
      expect(user.reload.name).to eq("Updated Name")
    end
  end

  describe "PATCH /api/v1/account/password" do
    it "changes password with valid current password" do
      patch "/api/v1/account/password",
            params: {
              current_password: "password123",
              password: "newpassword456",
              password_confirmation: "newpassword456"
            },
            headers: auth_headers(user),
            as: :json
      expect(response).to have_http_status(:ok)
      expect(user.reload.valid_password?("newpassword456")).to be(true)
      expect(user.password_set_at).to be_present
    end

    it "rejects wrong current password" do
      patch "/api/v1/account/password",
            params: {
              current_password: "wrong",
              password: "newpassword456",
              password_confirmation: "newpassword456"
            },
            headers: auth_headers(user),
            as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "notification preferences" do
    it "returns defaults" do
      get "/api/v1/account/notification_preferences", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      prefs = response.parsed_body["notificationPreferences"]
      expect(prefs["email_notifications"]).to eq(true)
      expect(prefs["weekly_reports"]).to eq(true)
      expect(prefs["marketing_emails"]).to eq(false)
      expect(prefs["link_alerts"]).to eq(true)
    end

    it "persists updates" do
      patch "/api/v1/account/notification_preferences",
            params: { notification_preferences: { marketing_emails: true, weekly_reports: false } },
            headers: auth_headers(user),
            as: :json
      expect(response).to have_http_status(:ok)
      prefs = response.parsed_body["notificationPreferences"]
      expect(prefs["marketing_emails"]).to eq(true)
      expect(prefs["weekly_reports"]).to eq(false)
    end
  end
end

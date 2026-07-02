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
    it "returns channel key defaults" do
      get "/api/v1/account/notification_preferences", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      prefs = response.parsed_body["notificationPreferences"]
      expect(prefs.keys).to match_array(User::NOTIFICATION_CHANNEL_KEYS)
      expect(prefs["push_link_alerts"]).to eq(true)
      expect(prefs["push_weekly_reports"]).to eq(true)
      expect(prefs["push_marketing"]).to eq(false)
      expect(prefs["email_link_alerts"]).to eq(true)
      expect(prefs["email_weekly_reports"]).to eq(true)
      expect(prefs["email_marketing"]).to eq(false)
    end

    it "persists individual channel toggles" do
      patch "/api/v1/account/notification_preferences",
            params: {
              notification_preferences: {
                push_marketing: true,
                email_weekly_reports: false,
                email_marketing: true
              }
            },
            headers: auth_headers(user),
            as: :json
      expect(response).to have_http_status(:ok)
      prefs = response.parsed_body["notificationPreferences"]
      expect(prefs["push_marketing"]).to eq(true)
      expect(prefs["email_weekly_reports"]).to eq(false)
      expect(prefs["email_marketing"]).to eq(true)
      expect(prefs["push_link_alerts"]).to eq(true)
    end

    it "migrates legacy preferences on read" do
      user.update!(
        notification_preferences: {
          "link_alerts" => false,
          "weekly_reports" => true,
          "marketing_emails" => true,
          "email_notifications" => false
        }
      )

      get "/api/v1/account/notification_preferences", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      prefs = response.parsed_body["notificationPreferences"]
      expect(prefs["push_link_alerts"]).to eq(false)
      expect(prefs["push_weekly_reports"]).to eq(true)
      expect(prefs["email_link_alerts"]).to eq(false)
      expect(prefs["email_weekly_reports"]).to eq(false)
      expect(prefs["email_marketing"]).to eq(false)
    end

    it "maps legacy keys on patch" do
      patch "/api/v1/account/notification_preferences",
            params: { notification_preferences: { link_alerts: false, marketing_emails: true } },
            headers: auth_headers(user),
            as: :json
      expect(response).to have_http_status(:ok)
      prefs = response.parsed_body["notificationPreferences"]
      expect(prefs["push_link_alerts"]).to eq(false)
      expect(prefs["email_link_alerts"]).to eq(false)
      expect(prefs["email_marketing"]).to eq(true)
    end
  end

  describe "PATCH /api/v1/account/active_workspace" do
    before do
      FeatureFlag.find_by(key: "workspaces").update!(enabled: true)
    end

    it "accepts workspace public_id" do
      workspace = user.active_workspace
      patch "/api/v1/account/active_workspace",
            params: { workspace_id: workspace.public_id },
            headers: auth_headers(user),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]["activeWorkspaceId"]).to eq(workspace.public_id)
    end
  end
end

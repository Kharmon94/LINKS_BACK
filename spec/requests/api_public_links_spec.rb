# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public link onboarding", type: :request do
  it "creates user and link" do
    expect do
      post "/api/links/create-with-account",
           params: {
             url: "https://example.com/path",
             name: "My Experience",
             user_name: "Jane",
             email: "jane@example.com"
           },
           as: :json
    end.to change(User, :count).by(1).and change(Link, :count).by(1)

    expect(response).to have_http_status(:ok)
    json = response.parsed_body
    expect(json["short_code"]).to be_present
    expect(json["token"]).to be_present
  end

  describe "with workspaces enabled" do
    before do
      FeatureFlag.find_by(key: "workspaces").update!(enabled: true)
    end

    it "assigns the default workspace to the created link" do
      post "/api/links/create-with-account",
           params: {
             url: "https://example.com/path",
             name: "My Experience",
             user_name: "Jane",
             email: "jane-ws@example.com"
           },
           as: :json

      expect(response).to have_http_status(:ok)
      user = User.find_by("lower(email) = ?", "jane-ws@example.com")
      link = user.links.order(created_at: :desc).first
      expect(link.workspace_id).to eq(user.active_workspace_id)
      expect(link.workspace_id).to be_present
    end
  end
end

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
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Links", type: :request do
  let(:user) do
    User.create!(
      email: "links@example.com",
      password: "password123",
      name: "Links User",
      subscription_tier: "free",
      role: "owner"
    )
  end

  let(:token) { JwtService.encode(user) }

  it "creates link from dashboard API" do
    expect do
      post "/api/v1/links",
           params: { link: { destination_url: "https://example.com", name: "Test" } },
           headers: { "Authorization" => "Bearer #{token}" },
           as: :json
    end.to change(Link, :count).by(1)
    expect(response).to have_http_status(:created)
  end

  it "rejects invalid url" do
    post "/api/v1/links",
         params: { link: { destination_url: "data:text/html,hi", name: "Bad" } },
         headers: { "Authorization" => "Bearer #{token}" },
         as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end

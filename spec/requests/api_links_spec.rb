# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Links", type: :request do
  let(:user) do
    User.create!(
      email: "links@example.com",
      password: "password123",
      name: "Links User",
      subscription_tier: "starter",
      role: "owner"
    )
  end

  let(:other_user) do
    User.create!(
      email: "other@example.com",
      password: "password123",
      name: "Other User",
      subscription_tier: "starter",
      role: "owner"
    )
  end

  let(:token) { JwtService.encode(user) }
  let(:other_token) { JwtService.encode(other_user) }

  let!(:campaign) do
    Campaign.create!(user: user, name: "Spring Sale", description: "Promo")
  end

  let!(:link) do
    user.links.create!(
      destination_url: "https://example.com",
      name: "Test Link",
      short_code: "link01",
      campaign: campaign,
      utm_source: "facebook",
      utm_medium: "social"
    )
  end

  describe "POST /api/v1/links" do
    it "creates link from dashboard API" do
      expect do
        post "/api/v1/links",
             params: { link: { destination_url: "https://example.com/new", name: "Test" } },
             headers: { "Authorization" => "Bearer #{token}" },
             as: :json
      end.to change(Link, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["link"]["fullShortUrl"]).to start_with("https://")
      expect(body["link"]["utmParams"]).to be_a(Hash)
    end

    it "creates link with custom short code and UTM params" do
      post "/api/v1/links",
           params: {
             link: {
               destination_url: "https://example.com/page",
               name: "Custom",
               short_code: "mycustom",
               utm_source: "twitter",
               utm_campaign: "launch"
             }
           },
           headers: { "Authorization" => "Bearer #{token}" },
           as: :json

      expect(response).to have_http_status(:created)
      created = response.parsed_body["link"]
      expect(created["shortCode"]).to eq("mycustom")
      expect(created["utmParams"]["source"]).to eq("twitter")
    end

    it "rejects invalid url" do
      post "/api/v1/links",
           params: { link: { destination_url: "data:text/html,hi", name: "Bad" } },
           headers: { "Authorization" => "Bearer #{token}" },
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects invalid short code format" do
      post "/api/v1/links",
           params: { link: { destination_url: "https://example.com", short_code: "BAD!" } },
           headers: { "Authorization" => "Bearer #{token}" },
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/links" do
    let!(:randomizer_link) do
      user.links.create!(
        link_type: "randomizer",
        name: "Randomizer",
        short_code: "rand01",
        pool_entries_attributes: [
          { destination_url: "https://example.com/a", weight: 50, position: 0 },
          { destination_url: "https://example.com/b", weight: 50, position: 1 }
        ]
      )
    end

    it "returns paginated links with filters" do
      get "/api/v1/links",
          params: { q: "Test", link_type: "single", page: 1, per_page: 10 },
          headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["links"].length).to eq(1)
      expect(body["links"].first["campaign"]["name"]).to eq("Spring Sale")
      expect(body["meta"]["total"]).to eq(1)
    end

    it "filters by link_type randomizer" do
      get "/api/v1/links",
          params: { link_type: "randomizer" },
          headers: { "Authorization" => "Bearer #{token}" }

      expect(response.parsed_body["links"].length).to eq(1)
      expect(response.parsed_body["links"].first["isRandomizer"]).to be(true)
    end
  end

  describe "GET /api/v1/links/:id" do
    it "returns link with campaign and utm params" do
      get "/api/v1/links/#{link.id}",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["link"]
      expect(body["campaign"]["id"]).to eq(campaign.id.to_s)
      expect(body["utmParams"]["source"]).to eq("facebook")
      expect(body["fullShortUrl"]).to start_with("https://")
    end

    it "returns 404 for another user's link" do
      get "/api/v1/links/#{link.id}",
          headers: { "Authorization" => "Bearer #{other_token}" },
          as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/links/:id" do
    it "updates link fields" do
      patch "/api/v1/links/#{link.id}",
            params: { link: { name: "Updated", utm_term: "shoes" } },
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["link"]["name"]).to eq("Updated")
      expect(response.parsed_body["link"]["utmParams"]["term"]).to eq("shoes")
    end
  end

  describe "DELETE /api/v1/links/:id" do
    it "deletes the link" do
      expect do
        delete "/api/v1/links/#{link.id}",
               headers: { "Authorization" => "Bearer #{token}" },
               as: :json
      end.to change(Link, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/links/:id/clicks" do
    before do
      link.click_events.create!(
        clicked_at: Time.current,
        device_type: "Mobile",
        browser: "Safari",
        os: "iOS",
        referrer: "https://twitter.com",
        ip_hash: "abc123"
      )
    end

    it "returns paginated click events" do
      get "/api/v1/links/#{link.id}/clicks",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["clicks"].length).to eq(1)
      expect(body["clicks"].first["device"]).to eq("Mobile")
      expect(body["meta"]["total"]).to eq(1)
    end

    it "returns 404 for another user's link" do
      get "/api/v1/links/#{link.id}/clicks",
          headers: { "Authorization" => "Bearer #{other_token}" },
          as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end

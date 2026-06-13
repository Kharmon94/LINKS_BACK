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

  describe "with workspaces enabled" do
    before do
      FeatureFlag.find_by(key: "workspaces").update!(enabled: true)
    end

    it "creates a link scoped to the active workspace" do
      workspace = user.active_workspace

      expect do
        post "/api/v1/links",
             params: { link: { destination_url: "https://example.com/ws", name: "Workspace Link" } },
             headers: { "Authorization" => "Bearer #{token}" },
             as: :json
      end.to change(Link, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(Link.last.workspace_id).to eq(workspace.id)
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

  describe "custom domains on links" do
    def flag!(key, enabled:)
      FeatureFlag.find_by!(key: key).update!(enabled: enabled)
    end

    let(:growth_user) do
      User.create!(
        email: "growth@example.com",
        password: "password123",
        name: "Growth User",
        subscription_tier: "growth",
        role: "owner"
      )
    end

    let(:growth_token) { JwtService.encode(growth_user) }

    let!(:verified_domain) do
      growth_user.custom_domains.create!(
        domain: "links.example.com",
        status: "verified",
        verified_at: Time.current
      )
    end

    before do
      flag!("custom_domains", enabled: true)
      flag!("randomizer", enabled: true)
    end

    it "creates single link with custom domain and returns custom shortUrl" do
      post "/api/v1/links",
           params: {
             link: {
               destination_url: "https://example.com/branded",
               name: "Branded",
               custom_domain_id: verified_domain.id
             }
           },
           headers: { "Authorization" => "Bearer #{growth_token}" },
           as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body["link"]
      expect(body["shortUrl"]).to start_with("links.example.com/")
      expect(body["customDomainId"]).to eq(verified_domain.id.to_s)
    end

    it "creates randomizer with custom domain" do
      post "/api/v1/links",
           params: {
             link: {
               name: "Branded Randomizer",
               link_type: "randomizer",
               custom_domain_id: verified_domain.id,
               pool_entries_attributes: [
                 { destination_url: "https://example.com/a", weight: 50, position: 0 },
                 { destination_url: "https://example.com/b", weight: 50, position: 1 }
               ]
             }
           },
           headers: { "Authorization" => "Bearer #{growth_token}" },
           as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body["link"]
      expect(body["isRandomizer"]).to be(true)
      expect(body["shortUrl"]).to start_with("links.example.com/")
    end

    it "ignores unverified custom_domain_id on create" do
      pending_domain = growth_user.custom_domains.create!(domain: "pending-links.example.com")

      post "/api/v1/links",
           params: {
             link: {
               destination_url: "https://example.com/pending",
               name: "Pending Domain",
               custom_domain_id: pending_domain.id
             }
           },
           headers: { "Authorization" => "Bearer #{growth_token}" },
           as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body["link"]
      expect(body["customDomainId"]).to be_nil
      expect(body["shortUrl"]).to include(ENV.fetch("SHORT_LINK_HOST", "links.blackcollar.io"))
    end

    it "updates link custom domain" do
      platform_link = growth_user.links.create!(
        destination_url: "https://example.com/x",
        name: "Assign Domain",
        short_code: "assign1"
      )

      patch "/api/v1/links/#{platform_link.id}",
            params: { link: { custom_domain_id: verified_domain.id } },
            headers: { "Authorization" => "Bearer #{growth_token}" },
            as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["link"]
      expect(body["customDomainId"]).to eq(verified_domain.id.to_s)
      expect(body["shortUrl"]).to eq("links.example.com/assign1")
    end

    it "clears custom domain on update" do
      branded = growth_user.links.create!(
        destination_url: "https://example.com/x",
        name: "Switch",
        short_code: "sw001",
        custom_domain: verified_domain
      )

      patch "/api/v1/links/#{branded.id}",
            params: { link: { custom_domain_id: nil } },
            headers: { "Authorization" => "Bearer #{growth_token}" },
            as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["link"]
      expect(body["customDomainId"]).to be_nil
      expect(body["shortUrl"]).not_to include("links.example.com")
    end

    it "updates randomizer custom domain without breaking pool" do
      randomizer = growth_user.links.create!(
        link_type: "randomizer",
        name: "Pool Brand",
        short_code: "pool1",
        custom_domain: verified_domain,
        pool_entries_attributes: [
          { destination_url: "https://example.com/a", weight: 50, position: 0 },
          { destination_url: "https://example.com/b", weight: 50, position: 1 }
        ]
      )

      patch "/api/v1/links/#{randomizer.id}",
            params: { link: { custom_domain_id: nil } },
            headers: { "Authorization" => "Bearer #{growth_token}" },
            as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["link"]
      expect(body["poolEntries"].length).to eq(2)
      expect(body["customDomainId"]).to be_nil
    end
  end
end

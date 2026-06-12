# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Redirects", type: :request do
  let(:short_link_host) { ENV.fetch("SHORT_LINK_HOST", "links.blackcollar.io") }

  let(:user) do
    User.create!(
      email: "redirect@example.com",
      password: "password123",
      name: "Redirect User",
      subscription_tier: "free",
      role: "owner"
    )
  end

  let!(:link) do
    user.links.create!(
      destination_url: "https://example.com/landing",
      name: "Test Link",
      short_code: "test01",
      utm_source: "newsletter",
      utm_medium: "email"
    )
  end

  it "redirects to destination with merged UTM params" do
    get "/#{link.short_code}", headers: {
      "HTTP_HOST" => short_link_host,
      "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
      "HTTP_REFERER" => "https://google.com"
    }

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to eq(
      "https://example.com/landing?utm_source=newsletter&utm_medium=email"
    )
  end

  it "returns 404 for unknown short code" do
    get "/abcd12", headers: { "HTTP_HOST" => short_link_host }
    expect(response).to have_http_status(:not_found)
  end

  it "redirects on the API host (not only SHORT_LINK_HOST)" do
    get "/#{link.short_code}", headers: { "HTTP_HOST" => "links-api-production.up.railway.app" }

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("example.com/landing")
  end

  it "records click event and increments clicks_count" do
    expect do
      get "/#{link.short_code}", headers: {
        "HTTP_HOST" => short_link_host,
        "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "HTTP_REFERER" => "https://google.com"
      }
    end.to change(ClickEvent, :count).by(1)

    link.reload
    expect(link.clicks_count).to eq(1)

    event = link.click_events.last
    expect(event.device_type).to eq("Desktop")
    expect(event.browser).to eq("Chrome")
    expect(event.os).to eq("Windows")
    expect(event.referrer).to eq("https://google.com")
    expect(event.ip_hash).to be_present
  end

  it "does not overwrite existing UTM params on destination" do
    link.update!(destination_url: "https://example.com/page?utm_source=existing")

    get "/#{link.short_code}", headers: { "HTTP_HOST" => short_link_host }

    expect(response.headers["Location"]).to eq("https://example.com/page?utm_source=existing&utm_medium=email")
  end

  it "redirects randomizer links to a weighted pool destination" do
    link.update!(
      link_type: "randomizer",
      pool_entries_attributes: [
        { destination_url: "https://example.com/a", weight: 50, position: 0 },
        { destination_url: "https://example.com/b", weight: 50, position: 1 }
      ]
    )

    allow_any_instance_of(Link).to receive(:pick_pool_entry).and_return(link.pool_entries.first)

    get "/#{link.short_code}", headers: { "HTTP_HOST" => short_link_host }

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to eq(
      "https://example.com/a?utm_source=newsletter&utm_medium=email"
    )
  end
end

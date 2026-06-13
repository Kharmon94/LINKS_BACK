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

  it "returns friendly HTML 404 for unknown short code" do
    get "/abcd12", headers: { "HTTP_HOST" => short_link_host }
    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Link not found")
    expect(response.body).to include(short_link_host)
  end

  it "redirects reserved app paths to the frontend SPA" do
    get "/analytics", headers: { "HTTP_HOST" => short_link_host }

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/analytics")
  end

  it "redirects on the API host (not only SHORT_LINK_HOST)" do
    api_host = "links-api-production.up.railway.app"
    original_api_host = ENV["API_HOST"]
    ENV["API_HOST"] = api_host

    get "/#{link.short_code}", headers: { "HTTP_HOST" => api_host }

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("example.com/landing")
  ensure
    if original_api_host.nil?
      ENV.delete("API_HOST")
    else
      ENV["API_HOST"] = original_api_host
    end
  end

  it "records click using client IP from X-Forwarded-For behind a trusted proxy" do
    client_ip = "203.0.113.99"
    direct_ip = "203.0.113.50"

    get "/#{link.short_code}", headers: {
      "HTTP_HOST" => short_link_host,
      "REMOTE_ADDR" => "10.0.0.5",
      "HTTP_X_FORWARDED_FOR" => client_ip,
      "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    event = link.click_events.last
    expect(event.ip_hash).to eq(Digest::SHA256.hexdigest(client_ip)[0, 16])
    expect(event.ip_hash).not_to eq(Digest::SHA256.hexdigest(direct_ip)[0, 16])
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

  it "stores geo from CDN country header" do
    get "/#{link.short_code}", headers: {
      "HTTP_HOST" => short_link_host,
      "HTTP_CF_IPCOUNTRY" => "US"
    }

    event = link.click_events.last
    expect(event.country).to eq("United States")
    expect(response).to have_http_status(:found)
  end

  it "does not overwrite existing UTM params on destination" do
    link.update!(destination_url: "https://example.com/page?utm_source=existing")

    get "/#{link.short_code}", headers: { "HTTP_HOST" => short_link_host }

    expect(response.headers["Location"]).to eq("https://example.com/page?utm_source=existing&utm_medium=email")
  end

  it "redirects randomizer links to a weighted pool destination and records pool attribution" do
    link.update!(
      link_type: "randomizer",
      pool_entries_attributes: [
        { destination_url: "https://example.com/a", weight: 50, position: 0 },
        { destination_url: "https://example.com/b", weight: 50, position: 1 }
      ]
    )
    entry = link.pool_entries.first

    allow_any_instance_of(Link).to receive(:resolve_redirect).and_return(
      Link::ResolvedRedirect.new(url: entry.destination_url, pool_entry: entry)
    )

    get "/#{link.short_code}", headers: { "HTTP_HOST" => short_link_host }

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to eq(
      "https://example.com/a?utm_source=newsletter&utm_medium=email"
    )

    event = link.click_events.last
    expect(event.pool_entry_id).to eq(entry.id)
    expect(event.destination_url).to eq(
      "https://example.com/a?utm_source=newsletter&utm_medium=email"
    )
  end

  describe "custom domain host isolation" do
    def flag!(key, enabled:)
      FeatureFlag.find_by!(key: key).update!(enabled: enabled)
    end

    let!(:custom_domain) do
      CustomDomain.create!(
        user: user,
        domain: "brand.example.com",
        status: "verified",
        verified_at: Time.current
      )
    end

    let!(:custom_link) do
      user.links.create!(
        destination_url: "https://example.com/custom",
        name: "Custom Host Link",
        short_code: "cust01",
        custom_domain: custom_domain
      )
    end

    before { flag!("custom_domains", enabled: true) }

    it "redirects single link on verified custom host" do
      get "/#{custom_link.short_code}", headers: { "HTTP_HOST" => custom_domain.domain }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to include("example.com/custom")
    end

    it "returns 404 for platform link on custom host" do
      get "/#{link.short_code}", headers: { "HTTP_HOST" => custom_domain.domain }

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for non-default custom link on platform host when another tenant shares the code" do
      other_user = User.create!(
        email: "ambiguous-redirect@example.com",
        password: "password123",
        name: "Ambiguous Redirect User",
        subscription_tier: "growth",
        role: "owner"
      )
      other_domain = other_user.custom_domains.create!(
        domain: "other-brand.example.com",
        status: "verified",
        verified_at: Time.current
      )
      other_user.links.create!(
        destination_url: "https://example.com/other-tenant",
        name: "Other Tenant Link",
        short_code: custom_link.short_code,
        custom_domain: other_domain
      )

      get "/#{custom_link.short_code}", headers: { "HTTP_HOST" => short_link_host }

      expect(response).to have_http_status(:not_found)
    end

    it "redirects default custom domain link on platform host" do
      custom_domain.update!(is_default: true)

      get "/#{custom_link.short_code}", headers: { "HTTP_HOST" => short_link_host }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to include("example.com/custom")
    end

    it "redirects a sole branded link on platform host when no platform-namespace match exists" do
      get "/#{custom_link.short_code}", headers: { "HTTP_HOST" => short_link_host }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to include("example.com/custom")
    end

    it "returns 404 on pending custom host without platform fallback" do
      pending_domain = CustomDomain.create!(
        user: user,
        domain: "pending.example.com",
        status: "pending"
      )

      get "/#{link.short_code}", headers: { "HTTP_HOST" => pending_domain.domain }

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 on unknown host" do
      get "/#{link.short_code}", headers: { "HTTP_HOST" => "unknown.example.com" }

      expect(response).to have_http_status(:not_found)
    end

    it "does not leak links across tenants sharing the same short code" do
      other_user = User.create!(
        email: "other-redirect@example.com",
        password: "password123",
        name: "Other Redirect User",
        subscription_tier: "growth",
        role: "owner"
      )
      other_domain = other_user.custom_domains.create!(
        domain: "other-brand.example.com",
        status: "verified",
        verified_at: Time.current
      )
      other_user.links.create!(
        destination_url: "https://example.com/other-tenant",
        name: "Other Tenant Link",
        short_code: custom_link.short_code,
        custom_domain: other_domain
      )

      get "/#{custom_link.short_code}", headers: { "HTTP_HOST" => custom_domain.domain }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to include("example.com/custom")
      expect(response.headers["Location"]).not_to include("example.com/other-tenant")
    end

    context "randomizer on custom host" do
      let!(:randomizer) do
        user.links.create!(
          link_type: "randomizer",
          name: "Custom Randomizer",
          short_code: "randcd",
          custom_domain: custom_domain,
          pool_entries_attributes: [
            { destination_url: "https://example.com/a", weight: 50, position: 0 },
            { destination_url: "https://example.com/b", weight: 50, position: 1 }
          ]
        )
      end

      before { flag!("randomizer", enabled: true) }

      it "redirects and records pool attribution" do
        entry = randomizer.pool_entries.first
        allow_any_instance_of(Link).to receive(:resolve_redirect).and_return(
          Link::ResolvedRedirect.new(url: entry.destination_url, pool_entry: entry)
        )

        get "/#{randomizer.short_code}", headers: { "HTTP_HOST" => custom_domain.domain }

        expect(response).to have_http_status(:found)
        event = randomizer.click_events.last
        expect(event.pool_entry_id).to eq(entry.id)
      end
    end
  end
end

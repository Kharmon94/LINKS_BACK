# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Custom Domains", type: :request do
  def flag!(key, enabled:)
    FeatureFlag.find_by!(key: key).update!(enabled: enabled)
  end

  let(:owner) do
    User.create!(
      email: "domains-owner@example.com",
      password: "password123",
      name: "Domain Owner",
      subscription_tier: "growth",
      role: "owner"
    )
  end

  let(:member) do
    User.create!(
      email: "domains-member@example.com",
      password: "password123",
      name: "Domain Member",
      subscription_tier: "growth",
      role: "member"
    )
  end

  before do
    flag!("custom_domains", enabled: true)
  end

  describe "POST /api/v1/custom_domains" do
    it "creates a pending custom domain" do
      expect do
        post "/api/v1/custom_domains",
             params: { domain: { domain: "https://Go.Links-Example.com/path" } },
             headers: auth_headers(owner),
             as: :json
      end.to change(CustomDomain, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body["domain"]
      expect(body["domain"]).to eq("go.links-example.com")
      expect(body["status"]).to eq("pending")
      expect(body["verificationToken"]).to be_present
    end

    it "rejects create when at tier domain limit" do
      10.times do |i|
        owner.custom_domains.create!(domain: "limit#{i}.example.com", status: "verified", verified_at: Time.current)
      end

      post "/api/v1/custom_domains",
           params: { domain: { domain: "one-too-many.example.com" } },
           headers: auth_headers(owner),
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to include("tier limit")
    end

    it "denies team members" do
      post "/api/v1/custom_domains",
           params: { domain: { domain: "member.example.com" } },
           headers: auth_headers(member),
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to include("Only team owners and admins")
    end
  end

  describe "POST /api/v1/custom_domains/:id/verify" do
    let!(:domain) { owner.custom_domains.create!(domain: "verify.example.com") }

    it "verifies with force=1 in test" do
      post "/api/v1/custom_domains/#{domain.id}/verify",
           params: { force: "1" },
           headers: auth_headers(owner),
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["domain"]["status"]).to eq("verified")
      expect(domain.reload.verified_at).to be_present
    end

    it "rejects verification without force when DNS is not configured" do
      post "/api/v1/custom_domains/#{domain.id}/verify",
           headers: auth_headers(owner),
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("DNS verification failed")
    end
  end

  describe "PATCH /api/v1/custom_domains/:id" do
    let!(:pending_domain) { owner.custom_domains.create!(domain: "pending-default.example.com") }

    it "rejects setting default on unverified domain" do
      patch "/api/v1/custom_domains/#{pending_domain.id}",
            params: { is_default: true },
            headers: auth_headers(owner),
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("verified")
      expect(pending_domain.reload.is_default).to be(false)
    end
  end
end

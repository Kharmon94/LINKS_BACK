# frozen_string_literal: true

require "rails_helper"

RSpec.describe Link, type: :model do
  let(:user) do
    User.create!(
      email: "link-scope@example.com",
      password: "password123",
      name: "Link Scope User",
      subscription_tier: "growth",
      role: "owner"
    )
  end

  let!(:verified_domain) do
    user.custom_domains.create!(
      domain: "brand.example.com",
      status: "verified",
      verified_at: Time.current
    )
  end

  describe "scoped short_code uniqueness" do
    it "allows the same short code on platform and a custom domain" do
      user.links.create!(
        destination_url: "https://example.com/platform",
        name: "Platform",
        short_code: "shared1"
      )

      custom_link = user.links.build(
        destination_url: "https://example.com/custom",
        name: "Custom",
        short_code: "shared1",
        custom_domain: verified_domain
      )

      expect(custom_link).to be_valid
      expect(custom_link.save).to be(true)
    end

    it "rejects duplicate short codes within the same custom domain scope" do
      user.links.create!(
        destination_url: "https://example.com/a",
        name: "First",
        short_code: "dupcd1",
        custom_domain: verified_domain
      )

      duplicate = user.links.build(
        destination_url: "https://example.com/b",
        name: "Second",
        short_code: "dupcd1",
        custom_domain: verified_domain
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:short_code]).to include("has already been taken")
    end

    it "rejects duplicate short codes on the platform scope" do
      user.links.create!(
        destination_url: "https://example.com/a",
        name: "First",
        short_code: "duppf1"
      )

      duplicate = user.links.build(
        destination_url: "https://example.com/b",
        name: "Second",
        short_code: "duppf1"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:short_code]).to include("has already been taken")
    end
  end
end

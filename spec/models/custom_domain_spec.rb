# frozen_string_literal: true

require "rails_helper"

RSpec.describe CustomDomain, type: :model do
  let(:user) do
    User.create!(
      email: "domain-model@example.com",
      password: "password123",
      name: "Domain Model User",
      subscription_tier: "growth",
      role: "owner"
    )
  end

  describe "normalization" do
    it "strips scheme, path, and lowercases domain" do
      domain = user.custom_domains.create!(domain: "HTTPS://WWW.Brand.EXAMPLE.com/path")

      expect(domain.domain).to eq("www.brand.example.com")
    end
  end

  describe "#set_as_default!" do
    it "requires verified status" do
      pending = user.custom_domains.create!(domain: "pending.example.com")

      expect { pending.set_as_default! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(pending.reload.is_default).to be(false)
    end

    it "sets default and clears other defaults when verified" do
      first = user.custom_domains.create!(
        domain: "first.example.com",
        status: "verified",
        verified_at: Time.current,
        is_default: true
      )
      second = user.custom_domains.create!(
        domain: "second.example.com",
        status: "verified",
        verified_at: Time.current
      )

      second.set_as_default!

      expect(second.reload.is_default).to be(true)
      expect(first.reload.is_default).to be(false)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Link short_code scoping", type: :model do
  let(:user) do
    User.create!(
      email: "scope@example.com",
      password: "password123",
      name: "Scope User",
      subscription_tier: "growth",
      role: "owner"
    )
  end

  let!(:domain_a) do
    user.custom_domains.create!(domain: "a.example.com", status: "verified", verified_at: Time.current)
  end

  let!(:domain_b) do
    user.custom_domains.create!(domain: "b.example.com", status: "verified", verified_at: Time.current)
  end

  it "allows the same short_code on different custom domains" do
    user.links.create!(
      destination_url: "https://example.com/1",
      name: "Platform",
      short_code: "promo"
    )
    user.links.create!(
      destination_url: "https://example.com/2",
      name: "Domain A",
      short_code: "promo",
      custom_domain: domain_a
    )
    link_b = user.links.build(
      destination_url: "https://example.com/3",
      name: "Domain B",
      short_code: "promo",
      custom_domain: domain_b
    )

    expect(link_b).to be_valid
    expect(link_b.save).to be(true)
  end

  it "blocks duplicate short_code within the same namespace" do
    user.links.create!(
      destination_url: "https://example.com/1",
      name: "First",
      short_code: "dup",
      custom_domain: domain_a
    )
    duplicate = user.links.build(
      destination_url: "https://example.com/2",
      name: "Second",
      short_code: "dup",
      custom_domain: domain_a
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:short_code]).to include("has already been taken")
  end

  %w[single randomizer].each do |link_type|
    it "scopes auto-generated codes per namespace for #{link_type}" do
      attrs = {
        name: "#{link_type} link",
        link_type: link_type,
        custom_domain: domain_a
      }
      if link_type == "randomizer"
        attrs[:pool_entries_attributes] = [
          { destination_url: "https://example.com/a", weight: 50, position: 0 },
          { destination_url: "https://example.com/b", weight: 50, position: 1 }
        ]
      else
        attrs[:destination_url] = "https://example.com"
      end

      link = user.links.create!(attrs)
      expect(link.short_code).to be_present

      other = user.links.build(attrs.merge(name: "other"))
      other.valid?
      expect(other.short_code).not_to eq(link.short_code) if other.short_code.present?
    end
  end
end

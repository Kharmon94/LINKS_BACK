# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasPublicId do
  let(:user) do
    User.create!(
      email: "public-id@example.com",
      password: "password123",
      name: "Public ID User",
      subscription_tier: "starter",
      role: "owner"
    )
  end

  let!(:link) do
    user.links.create!(destination_url: "https://example.com", name: "Example Link")
  end

  describe ".find_by_param!" do
    it "finds by public_id" do
      found = HasPublicId.find_by_param!(user.links, link.public_id)
      expect(found).to eq(link)
    end

    it "falls back to numeric id" do
      found = HasPublicId.find_by_param!(user.links, link.id.to_s)
      expect(found).to eq(link)
    end

    it "raises when not found" do
      expect do
        HasPublicId.find_by_param!(user.links, "not-a-real-id")
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "creation" do
    it "assigns a unique 12-char lowercase public_id" do
      created = user.links.create!(destination_url: "https://example.com/new", name: "New")
      expect(created.public_id).to match(/\A[a-z0-9]{12}\z/)
    end
  end
end

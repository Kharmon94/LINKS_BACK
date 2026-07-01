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

  describe "public_id generation" do
    it "assigns a unique 12-char lowercase alphanumeric public_id on create" do
      link = user.links.create!(
        destination_url: "https://example.com",
        name: "Test",
        short_code: "pub001"
      )

      expect(link.public_id).to match(/\A[a-z0-9]{12}\z/)
      expect(Link.where(public_id: link.public_id).count).to eq(1)
    end
  end

  describe ".find_by_param!" do
    let!(:link) do
      user.links.create!(
        destination_url: "https://example.com",
        name: "Lookup",
        short_code: "lkp001"
      )
    end

    it "finds by public_id" do
      found = Link.find_by_param!(user.links, link.public_id)
      expect(found).to eq(link)
    end

    it "falls back to numeric id" do
      found = Link.find_by_param!(user.links, link.id.to_s)
      expect(found).to eq(link)
    end

    it "raises when not found" do
      expect do
        Link.find_by_param!(user.links, "missingparam1")
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "HasPublicId.find_by_param! module helper" do
    it "delegates to the model class" do
      found = HasPublicId.find_by_param!(User, user.public_id)
      expect(found).to eq(user)
    end
  end
end

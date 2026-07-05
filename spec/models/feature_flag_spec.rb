# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeatureFlag, type: :model do
  let(:user) { User.create!(email: "flags@example.com", password: "password123", name: "Flags", role: "owner") }

  before do
    FeatureFlag.find_by!(key: "campaigns").update!(enabled: false)
  end

  describe ".enabled_for?" do
    it "inherits global when no override exists" do
      expect(described_class.enabled_for?(user, :campaigns)).to be false
    end

    it "forces on when global is off" do
      user.feature_flag_overrides.create!(feature_flag_key: "campaigns", enabled: true)
      user.clear_feature_flag_overrides_cache!

      expect(described_class.enabled_for?(user, :campaigns)).to be true
    end

    it "forces off when global is on" do
      FeatureFlag.find_by!(key: "campaigns").update!(enabled: true)
      user.feature_flag_overrides.create!(feature_flag_key: "campaigns", enabled: false)
      user.clear_feature_flag_overrides_cache!

      expect(described_class.enabled_for?(user, :campaigns)).to be false
    end
  end
end

RSpec.describe Permissions::Presenter, type: :model do
  let(:user_a) { User.create!(email: "a@example.com", password: "password123", name: "A", role: "owner") }
  let(:user_b) { User.create!(email: "b@example.com", password: "password123", name: "B", role: "owner") }

  before do
    FeatureFlag.find_by!(key: "campaigns").update!(enabled: false)
  end

  it "returns different permissions for users with different overrides" do
    user_a.feature_flag_overrides.create!(feature_flag_key: "campaigns", enabled: true)
    user_a.clear_feature_flag_overrides_cache!

    perms_a = described_class.for(user_a)[:permissions][:campaigns][:read]
    perms_b = described_class.for(user_b)[:permissions][:campaigns][:read]

    expect(perms_a).to be true
    expect(perms_b).to be false
  end
end

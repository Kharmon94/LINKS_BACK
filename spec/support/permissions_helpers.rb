# frozen_string_literal: true

module SpecHelpers
  module_function

  def seed_feature_flags!
    return if FeatureFlag.exists?

    [
      { key: "campaigns", enabled: false, description: "Campaigns", category: "product" },
      { key: "randomizer", enabled: false, description: "Randomizer", category: "product" },
      { key: "web_push", enabled: true, description: "Web push", category: "integrations" },
      { key: "workspaces", enabled: false, description: "Workspaces", category: "product" },
      { key: "custom_domains", enabled: false, description: "Custom domains", category: "integrations" }
    ].each do |attrs|
      FeatureFlag.create!(attrs)
    end
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{JwtService.encode(user)}" }
  end
end

RSpec.configure do |config|
  config.include SpecHelpers

  config.before do
    seed_feature_flags!
  end
end

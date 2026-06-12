# frozen_string_literal: true

module SpecHelpers
  module_function

  def seed_feature_flags!
    [
      { key: "campaigns", enabled: true, description: "Campaigns", category: "product" },
      { key: "randomizer", enabled: false, description: "Randomizer", category: "product" },
      { key: "web_push", enabled: true, description: "Web push", category: "integrations" },
      { key: "workspaces", enabled: false, description: "Workspaces", category: "product" },
      { key: "custom_domains", enabled: false, description: "Custom domains", category: "integrations" }
    ].each do |attrs|
      FeatureFlag.find_or_create_by!(key: attrs[:key]) do |flag|
        flag.enabled = attrs[:enabled]
        flag.description = attrs[:description]
        flag.category = attrs[:category]
      end
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

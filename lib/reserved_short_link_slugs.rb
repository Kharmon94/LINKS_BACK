# frozen_string_literal: true

# Top-level SPA path segments that match short-code shape [a-z0-9]{4,32}.
module ReservedShortLinkSlugs
  SLUGS = %w[
    admin
    analytics
    auth
    campaigns
    dashboard
    links
    pricing
    settings
    team
    workspaces
  ].freeze

  module_function

  def include?(slug)
    SLUGS.include?(slug.to_s)
  end
end

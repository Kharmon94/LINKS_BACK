# frozen_string_literal: true

module UrlValidator
  module_function

  BLOCKED_SCHEMES = %w[data javascript vbscript].freeze

  def self.safe_http_url?(value)
    return false if value.blank?

    uri = URI.parse(value.to_s.strip)
    return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    return false if BLOCKED_SCHEMES.include?(uri.scheme.to_s.downcase)

    true
  rescue URI::InvalidURIError
    false
  end
end

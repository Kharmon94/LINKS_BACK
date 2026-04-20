# frozen_string_literal: true

class Link < ApplicationRecord
  belongs_to :user

  validates :destination_url, presence: true
  validates :short_code, presence: true, uniqueness: true
  validate :destination_must_be_http_url

  before_validation :ensure_short_code, on: :create

  def as_json_for_client(host: ENV.fetch("SHORT_LINK_HOST", "links.blackcollar.io"))
    {
      id: id.to_s,
      name: name.presence || "Untitled",
      originalUrl: destination_url,
      shortCode: short_code,
      shortUrl: "#{host}/#{short_code}",
      clicks: clicks_count,
      createdAt: created_at&.strftime("%Y-%m-%d"),
      campaign: nil,
      isRandomizer: false
    }
  end

  private

  def destination_must_be_http_url
    return if UrlValidator.safe_http_url?(destination_url)

    errors.add(:destination_url, "must be a valid http(s) URL")
  end

  def ensure_short_code
    return if short_code.present?

    self.short_code = generate_unique_short_code
  end

  def generate_unique_short_code
    loop do
      code = SecureRandom.alphanumeric(6).downcase
      break code unless Link.exists?(short_code: code)
    end
  end
end

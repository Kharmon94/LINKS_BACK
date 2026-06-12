# frozen_string_literal: true

class ClickEvent < ApplicationRecord
  belongs_to :link

  validates :clicked_at, presence: true

  def as_json_for_client
    {
      id: id.to_s,
      timestamp: clicked_at&.iso8601,
      linkId: link_id.to_s,
      linkName: link.name.presence || link.short_code,
      shortUrl: link.as_json_for_client[:shortUrl],
      country: country,
      city: city,
      device: device_type,
      browser: browser,
      referrer: referrer.presence || "Direct"
    }
  end
end

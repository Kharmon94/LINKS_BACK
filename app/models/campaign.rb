# frozen_string_literal: true

class Campaign < ApplicationRecord
  include HasPublicId
  include AlertPreferences
  include AlertPreferences

  belongs_to :user
  belongs_to :workspace, optional: true
  has_many :links, dependent: :nullify

  validates :name, presence: true

  def total_clicks
    links.sum(:clicks_count)
  end

  def as_json_for_client(include_links: false)
    json = {
      id: id.to_s,
      publicId: public_id,
      name: name,
      description: description.to_s,
      linksCount: links.count,
      totalClicks: total_clicks,
      createdAt: created_at&.iso8601,
      workspaceId: workspace&.public_id
    }.merge(alert_preferences_as_json).merge(alert_preferences_as_json)
    json[:links] = links.order(created_at: :desc).map(&:as_json_for_client) if include_links
    json
  end
end

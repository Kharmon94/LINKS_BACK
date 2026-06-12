# frozen_string_literal: true

class Campaign < ApplicationRecord
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
      name: name,
      description: description.to_s,
      linksCount: links.count,
      totalClicks: total_clicks,
      createdAt: created_at&.iso8601,
      workspaceId: workspace_id&.to_s
    }
    json[:links] = links.order(created_at: :desc).map(&:as_json_for_client) if include_links
    json
  end
end

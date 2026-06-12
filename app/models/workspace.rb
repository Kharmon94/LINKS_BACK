# frozen_string_literal: true

class Workspace < ApplicationRecord
  belongs_to :team
  has_many :workspace_memberships, dependent: :destroy
  has_many :users, through: :workspace_memberships
  has_many :links, dependent: :nullify

  validates :name, presence: true

  def links_count
    links.count
  end

  def campaigns_count
    0
  end

  def as_json_for_client(include_members: false)
    json = {
      id: id.to_s,
      name: name,
      description: description.to_s,
      linksCount: links_count,
      campaignsCount: campaigns_count,
      createdAt: created_at&.iso8601
    }
    if include_members
      json[:members] = workspace_memberships.includes(:user).map do |membership|
        team_membership = team.team_memberships.find_by(user_id: membership.user_id)
        {
          id: membership.user_id.to_s,
          name: membership.user.name,
          email: membership.user.email,
          role: team_membership&.role || "member"
        }
      end
    end
    json
  end

  def as_json_for_admin
    {
      id: id.to_s,
      name: name,
      description: description.to_s,
      linksCount: links_count,
      createdAt: created_at&.iso8601
    }
  end
end

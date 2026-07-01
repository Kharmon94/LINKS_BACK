# frozen_string_literal: true

class Team < ApplicationRecord
  include HasPublicId

  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships
  has_many :team_invitations, dependent: :destroy
  has_many :workspaces, dependent: :destroy

  validates :name, presence: true

  def owner_membership
    team_memberships.find_by(role: "owner") || team_memberships.order(:created_at).first
  end

  def as_json_for_admin(detail: false, owner_email: nil)
    member_count = if has_attribute?(:members_count)
                     read_attribute(:members_count).to_i
                   else
                     team_memberships.count
                   end
    workspace_count = if has_attribute?(:workspaces_count)
                        read_attribute(:workspaces_count).to_i
                      else
                        workspaces.count
                      end
    owner = owner_email || owner_membership&.user&.email

    base = {
      id: id.to_s,
      publicId: public_id,
      name: name,
      personal: personal,
      memberCount: member_count,
      workspaceCount: workspace_count,
      ownerEmail: owner,
      createdAt: created_at&.iso8601
    }

    return base unless detail

    base.merge(
      members: team_memberships.includes(:user).order(:created_at).map(&:as_json_for_admin),
      invitations: team_invitations.pending.order(created_at: :desc).map(&:as_json_for_admin),
      workspaces: workspaces.order(:created_at).map(&:as_json_for_admin)
    )
  end
end

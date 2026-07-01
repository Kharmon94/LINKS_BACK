# frozen_string_literal: true

class TeamMembership < ApplicationRecord
  ROLES = %w[owner admin member].freeze

  belongs_to :team
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :team_id }

  after_update :sync_user_role, if: :saved_change_to_role?

  def as_json_for_client
    {
      id: user.public_id,
      name: user.name,
      email: user.email,
      role: role,
      joinedAt: created_at&.iso8601
    }
  end

  def as_json_for_admin
    as_json_for_client
  end

  private

  def sync_user_role
    return unless team.personal?

    user.update!(role: role) if user.role != role
  end
end

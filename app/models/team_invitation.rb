# frozen_string_literal: true

class TeamInvitation < ApplicationRecord
  ROLES = %w[admin member].freeze

  belongs_to :team
  belongs_to :invited_by, class_name: "User"

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :token, presence: true, uniqueness: true

  before_validation :ensure_token, on: :create
  before_validation :set_expiration, on: :create

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }

  def pending?
    accepted_at.nil? && expires_at > Time.current
  end

  def accept!(user)
    raise ActiveRecord::RecordInvalid, self unless pending?
    raise ArgumentError, "Email does not match invitation" unless user.email.downcase == email.downcase

    transaction do
      membership = team.team_memberships.find_or_initialize_by(user: user)
      membership.role = role
      membership.save!

      team.workspaces.find_each do |workspace|
        workspace.workspace_memberships.find_or_create_by!(user: user)
      end

      update!(accepted_at: Time.current)
      membership
    end
  end

  def as_json_for_client
    {
      id: id.to_s,
      email: email,
      role: role,
      expiresAt: expires_at&.iso8601,
      invitedAt: created_at&.iso8601
    }
  end

  def as_json_for_preview
    {
      email: email,
      role: role,
      teamName: team.name,
      expired: !pending?
    }
  end

  def as_json_for_admin
    {
      id: id.to_s,
      email: email,
      role: role,
      expiresAt: expires_at&.iso8601,
      invitedAt: created_at&.iso8601
    }
  end

  private

  def ensure_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end
end

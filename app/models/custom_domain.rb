# frozen_string_literal: true

class CustomDomain < ApplicationRecord
  STATUSES = %w[pending verified].freeze
  CUSTOM_DOMAIN_TIERS = %w[growth enterprise].freeze

  belongs_to :user
  has_many :links, dependent: :nullify

  validates :domain, presence: true, uniqueness: true, format: {
    with: /\A[a-z0-9]+([\-.][a-z0-9]+)*\.[a-z]{2,}\z/i,
    message: "must be a valid domain name"
  }
  validates :status, inclusion: { in: STATUSES }
  validates :verification_token, presence: true

  before_validation :normalize_domain
  before_validation :ensure_verification_token, on: :create

  scope :verified, -> { where(status: "verified") }

  def verified?
    status == "verified"
  end

  def verify!
    update!(status: "verified", verified_at: Time.current)
  end

  def set_as_default!
    unless verified?
      errors.add(:base, "Domain must be verified before setting as default")
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      user.custom_domains.where.not(id: id).update_all(is_default: false)
      update!(is_default: true)
    end
  end

  def as_json_for_client
    {
      id: id.to_s,
      domain: domain,
      status: status,
      isDefault: is_default,
      verificationToken: verification_token,
      createdAt: created_at&.iso8601,
      verifiedAt: verified_at&.iso8601
    }
  end

  def self.allowed_for?(user)
    FeatureFlag.enabled?(:custom_domains) &&
      CUSTOM_DOMAIN_TIERS.include?(user.billing_account.subscription_tier)
  end

  private

  def normalize_domain
    self.domain = domain.to_s.strip.downcase.delete_prefix("https://").delete_prefix("http://").split("/").first
  end

  def ensure_verification_token
    self.verification_token ||= SecureRandom.hex(16)
  end
end

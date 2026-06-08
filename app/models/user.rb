# frozen_string_literal: true

class User < ApplicationRecord
  TIER_LIMITS = {
    "free" => { max_links: 1, max_campaigns: 0 },
    "starter" => { max_links: 20, max_campaigns: 2 },
    "growth" => { max_links: Float::INFINITY, max_campaigns: Float::INFINITY },
    "enterprise" => { max_links: Float::INFINITY, max_campaigns: Float::INFINITY }
  }.freeze

  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :links, dependent: :destroy
  has_many :web_push_subscriptions, dependent: :destroy

  validates :name, presence: true
  validates :subscription_tier, inclusion: { in: TIER_LIMITS.keys }
  validates :role, inclusion: { in: %w[owner admin member] }

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    email = conditions.delete(:email)&.strip&.downcase
    where(conditions).where(["lower(email) = ?", email]).first
  end

  def self.from_google_omniauth(auth)
    email = auth.info.email.to_s.strip.downcase
    user = find_by(provider: "google_oauth2", uid: auth.uid)
    user ||= find_by("lower(email) = ?", email)
    if user
      user.update!(provider: "google_oauth2", uid: auth.uid) if user.uid.blank?
      user
    else
      create!(
        email: email,
        name: auth.info.name.presence || email.split("@").first,
        password: Devise.friendly_token(32),
        provider: "google_oauth2",
        uid: auth.uid,
        subscription_tier: "free",
        role: "owner"
      )
    end
  end

  def assign_magic_link!
    update!(
      magic_link_token: SecureRandom.urlsafe_base64(32),
      magic_link_expires_at: 15.minutes.from_now
    )
  end

  def clear_magic_link!
    update!(magic_link_token: nil, magic_link_expires_at: nil)
  end

  def magic_link_valid?(token)
    magic_link_token.present? && magic_link_token == token &&
      magic_link_expires_at.present? && magic_link_expires_at > Time.current
  end

  def password_set?
    password_set_at.present?
  end

  def at_link_limit?
    limit = TIER_LIMITS[subscription_tier][:max_links]
    return false if limit == Float::INFINITY

    links.count >= limit
  end

  def as_json_for_client
    base = {
      id: id.to_s,
      email: email,
      name: name,
      subscriptionTier: subscription_tier,
      role: role,
      admin: admin
    }
    base.merge!(Permissions::Presenter.for(self))
    base
  end

  def as_json_for_admin(include_recent_links: false)
    base = as_json_for_client.merge(
      linksCount: links.count,
      createdAt: created_at&.iso8601,
      provider: provider,
      stripeCustomerId: stripe_customer_id
    )
    if include_recent_links
      base[:recentLinks] = links.order(created_at: :desc).limit(5).map do |link|
        json = link.as_json_for_client
        {
          id: json[:id],
          name: json[:name],
          shortCode: json[:shortCode],
          shortUrl: json[:shortUrl],
          clicks: json[:clicks],
          createdAt: json[:createdAt]
        }
      end
    end
    base
  end
end

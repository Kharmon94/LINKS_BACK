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
  has_many :campaigns, dependent: :destroy
  has_many :web_push_subscriptions, dependent: :destroy
  has_many :billing_events, dependent: :destroy
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships
  has_many :workspace_memberships, dependent: :destroy
  has_many :workspaces, through: :workspace_memberships
  has_many :custom_domains, dependent: :destroy
  belongs_to :active_workspace, class_name: "Workspace", optional: true

  after_create :provision_team!

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

  DEFAULT_NOTIFICATION_PREFERENCES = {
    "email_notifications" => true,
    "weekly_reports" => true,
    "marketing_emails" => false,
    "link_alerts" => true
  }.freeze

  def password_set?
    password_set_at.present?
  end

  def notification_preferences_hash
    DEFAULT_NOTIFICATION_PREFERENCES.merge((notification_preferences || {}).stringify_keys)
  end

  def at_link_limit?
    limit = TIER_LIMITS[subscription_tier][:max_links]
    return false if limit == Float::INFINITY

    links.count >= limit
  end

  def primary_team_membership
    team_memberships.joins(:team).order("teams.personal DESC, team_memberships.created_at ASC").first
  end

  def primary_team
    primary_team_membership&.team
  end

  def team_role
    primary_team_membership&.role || role
  end

  def scoped_links
    if FeatureFlag.enabled?(:workspaces) && active_workspace_id.present?
      links.where(workspace_id: active_workspace_id)
    else
      links
    end
  end

  def accessible_workspaces
    return Workspace.none unless primary_team

    workspaces.joins(:team).where(teams: { id: primary_team.id }).distinct
  end

  def at_campaign_limit?
    limit = TIER_LIMITS[subscription_tier][:max_campaigns]
    return false if limit == Float::INFINITY

    campaigns.count >= limit
  end

  def as_json_for_client
    base = {
      id: id.to_s,
      email: email,
      name: name,
      subscriptionTier: subscription_tier,
      role: team_role,
      admin: admin,
      activeWorkspaceId: active_workspace_id&.to_s
    }
    base.merge!(Permissions::Presenter.for(self))
    base
  end

  private

  def provision_team!
    TeamProvisioner.provision_for!(self)
  end

  public

  def as_json_for_admin(include_recent_links: false)
    membership = primary_team_membership
    base = as_json_for_client.merge(
      linksCount: links.count,
      createdAt: created_at&.iso8601,
      provider: provider,
      stripeCustomerId: stripe_customer_id,
      teamId: membership&.team_id&.to_s,
      teamName: membership&.team&.name,
      membershipRole: membership&.role
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

# frozen_string_literal: true

class User < ApplicationRecord
  include HasPublicId

  TIER_LIMITS = {
    "free" => { max_links: 1, max_campaigns: 0, max_custom_domains: 0 },
    "starter" => { max_links: 20, max_campaigns: 2, max_custom_domains: 0 },
    "growth" => { max_links: Float::INFINITY, max_campaigns: Float::INFINITY, max_custom_domains: 10 },
    "pro" => { max_links: Float::INFINITY, max_campaigns: Float::INFINITY, max_custom_domains: 10 },
    "enterprise" => { max_links: Float::INFINITY, max_campaigns: Float::INFINITY, max_custom_domains: Float::INFINITY }
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
  has_many :feature_flag_overrides, class_name: "UserFeatureFlagOverride", dependent: :destroy
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

  NOTIFICATION_CHANNEL_KEYS = %w[
    push_link_alerts push_weekly_reports push_marketing
    email_link_alerts email_weekly_reports email_marketing
  ].freeze

  LEGACY_NOTIFICATION_KEYS = %w[
    email_notifications weekly_reports marketing_emails link_alerts
  ].freeze

  DEFAULT_NOTIFICATION_PREFERENCES = {
    "push_link_alerts" => true,
    "push_weekly_reports" => true,
    "push_marketing" => false,
    "email_link_alerts" => true,
    "email_weekly_reports" => true,
    "email_marketing" => false
  }.freeze

  LEGACY_NOTIFICATION_DEFAULTS = {
    "email_notifications" => true,
    "weekly_reports" => true,
    "marketing_emails" => false,
    "link_alerts" => true
  }.freeze

  def self.cast_notification_bool(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def password_set?
    password_set_at.present?
  end

  def notification_preferences_hash
    stored = (notification_preferences || {}).stringify_keys
    result = DEFAULT_NOTIFICATION_PREFERENCES.dup

    NOTIFICATION_CHANNEL_KEYS.each do |key|
      result[key] = self.class.cast_notification_bool(stored[key]) if stored.key?(key)
    end

    legacy = LEGACY_NOTIFICATION_DEFAULTS.merge(stored.slice(*LEGACY_NOTIFICATION_KEYS))
    link_alerts = self.class.cast_notification_bool(legacy["link_alerts"])
    weekly_reports = self.class.cast_notification_bool(legacy["weekly_reports"])
    marketing_emails = self.class.cast_notification_bool(legacy["marketing_emails"])
    email_notifications = self.class.cast_notification_bool(legacy["email_notifications"])

    result["push_link_alerts"] = link_alerts unless stored.key?("push_link_alerts")
    result["push_weekly_reports"] = weekly_reports unless stored.key?("push_weekly_reports")
    result["push_marketing"] = false unless stored.key?("push_marketing")

    unless stored.key?("email_link_alerts")
      result["email_link_alerts"] = link_alerts && email_notifications
    end
    unless stored.key?("email_weekly_reports")
      result["email_weekly_reports"] = weekly_reports && email_notifications
    end
    unless stored.key?("email_marketing")
      result["email_marketing"] = marketing_emails && email_notifications
    end

    result
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
    if FeatureFlag.enabled_for?(self, :workspaces) && active_workspace_id.present?
      links.where(workspace_id: active_workspace_id)
    else
      links
    end
  end

  def accessible_workspaces
    workspaces.distinct
  end

  def assign_default_workspace!(record, workspace_id: nil)
    return unless FeatureFlag.enabled_for?(self, :workspaces)
    return unless record.respond_to?(:workspace=)

    workspace = if workspace_id.present?
                  HasPublicId.find_by_param!(accessible_workspaces, workspace_id)
                elsif record.workspace_id.present?
                  accessible_workspaces.find_by(id: record.workspace_id)
                else
                  active_workspace || accessible_workspaces.first
                end
    record.workspace = workspace if workspace
  end

  def at_campaign_limit?
    limit = TIER_LIMITS[subscription_tier][:max_campaigns]
    return false if limit == Float::INFINITY

    campaigns.count >= limit
  end

  def billing_account
    team = primary_team
    return self unless team

    team.owner_membership&.user || self
  end

  def at_custom_domain_limit?
    account = billing_account
    limit = TIER_LIMITS[account.subscription_tier][:max_custom_domains]
    return false if limit == Float::INFINITY

    account.custom_domains.count >= limit
  end

  def as_json_for_client
    base = {
      id: id.to_s,
      publicId: public_id,
      email: email,
      name: name,
      subscriptionTier: subscription_tier,
      role: team_role,
      admin: admin,
      activeWorkspaceId: active_workspace&.public_id,
      pwaInstalledAt: pwa_installed_at&.iso8601
    }
    base.merge!(Permissions::Presenter.for(self))
    base
  end

  def feature_flag_overrides_by_key
    @feature_flag_overrides_by_key ||= feature_flag_overrides.index_by(&:feature_flag_key)
  end

  def clear_feature_flag_overrides_cache!
    @feature_flag_overrides_by_key = nil
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
      teamId: membership&.team&.public_id,
      teamName: membership&.team&.name,
      membershipRole: membership&.role
    )
    if include_recent_links
      base[:recentLinks] = links.order(created_at: :desc).limit(5).map do |link|
        json = link.as_json_for_client
        {
          id: json[:id],
          publicId: json[:publicId],
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

# frozen_string_literal: true

module Permissions
  # Single source of truth for authorization rules shared by Ability and Presenter.
  class Rules
    BILLING_ROLES = %w[owner].freeze

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def apply_to(ability)
      return if user.nil?

      apply_solo_user_rules(ability)
      apply_platform_admin_rules(ability) if user.admin?
      AbilityTeamRoles.apply_stubs(ability, user)
    end

    def platform_admin?
      user.admin?
    end

    def billing_allowed?
      BILLING_ROLES.include?(user.role)
    end

    def portal_allowed?
      billing_allowed? && user.stripe_customer_id.present?
    end

    def can_create_link?
      !user.at_link_limit?
    end

    def feature_enabled?(key)
      FeatureFlag.enabled?(key)
    end

    def permissions_hash
      {
        platformAdmin: platform_admin?,
        links: link_permissions,
        campaigns: campaign_permissions,
        team: team_permissions,
        workspaces: workspace_permissions,
        settings: settings_permissions,
        analytics: { read: true },
        admin: admin_permissions
      }
    end

    def limits_hash
      tier_limits = User::TIER_LIMITS[user.subscription_tier] || User::TIER_LIMITS["free"]
      max_links = tier_limits[:max_links]
      max_campaigns = tier_limits[:max_campaigns]

      {
        links: {
          used: user.links.count,
          max: max_links == Float::INFINITY ? nil : max_links
        },
        campaigns: {
          used: 0,
          max: max_campaigns == Float::INFINITY ? nil : max_campaigns
        }
      }
    end

    private

    def link_permissions
      {
        read: true,
        create: can_create_link?,
        update: true,
        destroy: true
      }
    end

    def campaign_permissions
      enabled = feature_enabled?(:campaigns)
      {
        read: enabled,
        create: enabled,
        update: enabled,
        destroy: enabled
      }
    end

    def team_permissions
      enabled = feature_enabled?(:workspaces)
      {
        read: enabled,
        invite: enabled && user.role.in?(%w[owner admin]),
        manage: enabled && user.role == "owner"
      }
    end

    def workspace_permissions
      enabled = feature_enabled?(:workspaces)
      {
        read: enabled,
        create: enabled && user.role.in?(%w[owner admin]),
        update: enabled && user.role.in?(%w[owner admin]),
        destroy: enabled && user.role == "owner"
      }
    end

    def settings_permissions
      {
        billing: billing_allowed?,
        domains: feature_enabled?(:custom_domains) && user.role.in?(%w[owner admin])
      }
    end

    def admin_permissions
      {
        users: platform_admin?,
        links: platform_admin?
      }
    end

    def apply_solo_user_rules(ability)
      ability.can %i[show update destroy], Link, user_id: user.id
      ability.can :create, Link unless user.at_link_limit?

      ability.can :create, WebPushSubscription, user_id: user.id
      ability.can :destroy, WebPushSubscription, user_id: user.id

      ability.can :show, User, id: user.id

      ability.can :create, :checkout if billing_allowed?
      ability.can :create, :portal if portal_allowed?

      ability.can :read, Plan
    end

    def apply_platform_admin_rules(ability)
      ability.can %i[index show update], User
      ability.cannot :create, User
      ability.cannot :destroy, User

      ability.can %i[index show update], FeatureFlag
      ability.cannot %i[create destroy], FeatureFlag

      ability.can %i[index show destroy], Link

      ability.can %i[index show destroy], WebPushSubscription

      ability.can :read, :admin_dashboard
      ability.can :read, :admin_teams
    end
  end
end

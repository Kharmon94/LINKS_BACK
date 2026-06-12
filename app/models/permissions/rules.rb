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
      BILLING_ROLES.include?(user.team_role)
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
          used: user.campaigns.count,
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
      can_manage = enabled && user.team_role.in?(%w[owner admin])
      {
        read: enabled,
        create: can_manage && !user.at_campaign_limit?,
        update: can_manage,
        destroy: can_manage
      }
    end

    def team_permissions
      enabled = feature_enabled?(:workspaces)
      {
        read: enabled,
        invite: enabled && user.team_role.in?(%w[owner admin]),
        manage: enabled && user.team_role == "owner"
      }
    end

    def workspace_permissions
      enabled = feature_enabled?(:workspaces)
      {
        read: enabled,
        create: enabled && user.team_role.in?(%w[owner admin]),
        update: enabled && user.team_role.in?(%w[owner admin]),
        destroy: enabled && user.team_role == "owner"
      }
    end

    def settings_permissions
      {
        billing: billing_allowed?,
        domains: CustomDomain.allowed_for?(user) && user.team_role.in?(%w[owner admin])
      }
    end

    def admin_permissions
      {
        users: platform_admin?,
        links: platform_admin?
      }
    end

    def apply_solo_user_rules(ability)
      unless feature_enabled?(:workspaces)
        ability.can %i[show update destroy], Link, user_id: user.id
        ability.can :create, Link unless user.at_link_limit?
      end

      ability.can :create, WebPushSubscription, user_id: user.id
      ability.can :destroy, WebPushSubscription, user_id: user.id

      ability.can %i[show update], User, id: user.id

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
      ability.can :read, :admin_health
      ability.can :read, :admin_teams
      ability.can :read, :admin_billing
      ability.can :create, :admin_billing_portal
      ability.can :create, :admin_billing_cancel

      ability.can :read, :admin_campaigns
      ability.can :destroy, :admin_campaigns
      ability.can :read, :admin_workspaces
      ability.can :destroy, :admin_workspaces
      ability.can :read, :admin_custom_domains
      ability.can :destroy, :admin_custom_domains
      ability.can :read, :admin_web_push
      ability.can :destroy, :admin_web_push
    end
  end
end

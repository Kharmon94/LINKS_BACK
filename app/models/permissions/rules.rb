# frozen_string_literal: true

module Permissions
  # Single source of truth for authorization rules shared by Ability and Presenter.
  class Rules
    CAMPAIGN_MANAGER_ROLES = %w[owner admin].freeze

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def apply_to(ability)
      return if user.nil?

      apply_solo_user_rules(ability)
      apply_collaboration_rules(ability)
      apply_platform_admin_rules(ability) if user.admin?
    end

    def platform_admin?
      user.admin?
    end

    def billing_allowed?
      user.id == user.billing_account.id
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
        analytics: { read: analytics_allowed? },
        admin: admin_permissions
      }
    end

    def limits_hash
      account = user.billing_account
      tier_limits = User::TIER_LIMITS[account.subscription_tier] || User::TIER_LIMITS["free"]
      max_links = tier_limits[:max_links]
      max_campaigns = tier_limits[:max_campaigns]
      max_domains = tier_limits[:max_custom_domains]

      {
        links: {
          used: user.links.count,
          max: max_links == Float::INFINITY ? nil : max_links
        },
        campaigns: {
          used: user.campaigns.count,
          max: max_campaigns == Float::INFINITY ? nil : max_campaigns
        },
        domains: {
          used: account.custom_domains.count,
          max: max_domains == Float::INFINITY ? nil : max_domains
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
      can_manage = enabled && user.team_role.in?(CAMPAIGN_MANAGER_ROLES)
      {
        read: enabled,
        create: can_manage && !user.at_campaign_limit?,
        update: can_manage,
        destroy: can_manage
      }
    end

    def team_permissions
      enabled = feature_enabled?(:workspaces)
      can_manage_members = enabled && user.team_role.in?(CAMPAIGN_MANAGER_ROLES)
      {
        read: enabled,
        invite: can_manage_members,
        removeMember: can_manage_members,
        manage: enabled && user.team_role == "owner"
      }
    end

    def workspace_permissions
      enabled = feature_enabled?(:workspaces)
      {
        read: enabled,
        create: enabled && user.team_role.in?(CAMPAIGN_MANAGER_ROLES),
        update: enabled && user.team_role.in?(CAMPAIGN_MANAGER_ROLES),
        destroy: enabled && user.team_role == "owner"
      }
    end

    def settings_permissions
      {
        billing: billing_allowed?,
        portal: portal_allowed?,
        domains: CustomDomain.allowed_for?(user) && user.team_role.in?(CAMPAIGN_MANAGER_ROLES)
      }
    end

    def admin_permissions
      return { users: false, links: false } unless platform_admin?

      {
        users: true,
        links: true
      }
    end

    def analytics_allowed?
      true
    end

    def apply_solo_user_rules(ability)
      unless feature_enabled?(:workspaces)
        ability.can %i[show update destroy], Link, user_id: user.id
        ability.can :create, Link unless user.at_link_limit?
      end

      if feature_enabled?(:web_push)
        ability.can :create, WebPushSubscription, user_id: user.id
        ability.can :destroy, WebPushSubscription, user_id: user.id
      end

      ability.can %i[show update], User, id: user.id

      ability.can :create, :checkout if billing_allowed?
      ability.can :create, :portal if portal_allowed?

      ability.can :read, Plan
    end

    def apply_collaboration_rules(ability)
      apply_workspace_rules(ability)
      apply_campaign_rules(ability)
      apply_team_rules(ability)
      apply_custom_domain_rules(ability)
      apply_analytics_rules(ability)
    end

    def apply_workspace_rules(ability)
      return unless feature_enabled?(:workspaces)

      workspace_ids = user.accessible_workspaces.pluck(:id)
      return if workspace_ids.empty?

      ability.can %i[read update destroy], Link, workspace_id: workspace_ids
      ability.can :create, Link, workspace_id: workspace_ids unless user.at_link_limit?

      ability.can :read, Workspace, id: workspace_ids

      managed_team_ids = user.team_memberships.where(role: CAMPAIGN_MANAGER_ROLES).pluck(:team_id)
      owner_team_ids = user.team_memberships.where(role: "owner").pluck(:team_id)
      member_team_ids = user.team_memberships.pluck(:team_id)

      ability.can %i[create update], Workspace, team_id: managed_team_ids if managed_team_ids.any?
      ability.can :destroy, Workspace, team_id: owner_team_ids if owner_team_ids.any?

      ability.can :read, TeamMembership, team_id: member_team_ids if member_team_ids.any?
      ability.can :update, TeamMembership, team_id: owner_team_ids if owner_team_ids.any?
      ability.can :destroy, TeamMembership, team_id: managed_team_ids if managed_team_ids.any?

      ability.can :read, TeamInvitation, team_id: member_team_ids if member_team_ids.any?
      ability.can :create, TeamInvitation, team_id: managed_team_ids if managed_team_ids.any?
    end

    def apply_campaign_rules(ability)
      return unless feature_enabled?(:campaigns)

      if feature_enabled?(:workspaces)
        workspace_ids = user.accessible_workspaces.pluck(:id)
        return if workspace_ids.empty?

        ability.can :read, Campaign, workspace_id: workspace_ids
        ability.can :assign_links, Campaign, workspace_id: workspace_ids
        ability.can :unassign_links, Campaign, workspace_id: workspace_ids

        return unless user.team_role.in?(CAMPAIGN_MANAGER_ROLES)

        ability.can %i[update destroy], Campaign, workspace_id: workspace_ids
        ability.can :create, Campaign, workspace_id: workspace_ids unless user.at_campaign_limit?
      else
        ability.can :read, Campaign, user_id: user.id
        ability.can :assign_links, Campaign, user_id: user.id
        ability.can :unassign_links, Campaign, user_id: user.id

        return unless user.team_role.in?(CAMPAIGN_MANAGER_ROLES)

        ability.can %i[update destroy], Campaign, user_id: user.id
        ability.can :create, Campaign unless user.at_campaign_limit?
      end
    end

    def apply_team_rules(ability)
      return unless feature_enabled?(:workspaces)

      ability.can :read, :team if user.primary_team.present?
      ability.can :accept, TeamInvitation
    end

    def apply_custom_domain_rules(ability)
      return unless CustomDomain.allowed_for?(user)
      return unless user.team_role.in?(CAMPAIGN_MANAGER_ROLES)

      billing_id = user.billing_account.id
      ability.can %i[create update destroy], CustomDomain, user_id: billing_id
    end

    def apply_analytics_rules(ability)
      ability.can :read, :analytics if analytics_allowed?
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

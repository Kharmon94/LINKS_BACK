# frozen_string_literal: true

module AbilityTeamRoles
  module_function

  def apply_stubs(ability, user)
    apply_workspace_rules(ability, user)
    apply_campaign_rules(ability, user)
    apply_team_rules(ability, user)
    apply_custom_domain_rules(ability, user)
    apply_analytics_rules(ability, user)
    ability
  end

  def apply_workspace_rules(ability, user)
    return unless FeatureFlag.enabled?(:workspaces)

    workspace_ids = user.accessible_workspaces.select(:id)

    ability.can %i[read update destroy], Link, workspace_id: workspace_ids
    ability.can :create, Link, workspace_id: workspace_ids unless user.at_link_limit?

    ability.can :read, Workspace, id: workspace_ids
    ability.can %i[create update destroy], Workspace, team_id: user.primary_team&.id if user.team_role.in?(%w[owner admin])
    ability.can :destroy, Workspace, team_id: user.primary_team&.id if user.team_role == "owner"

    ability.can :read, TeamMembership, team_id: user.primary_team&.id
    ability.can :update, TeamMembership, team_id: user.primary_team&.id if user.team_role == "owner"
    ability.can :destroy, TeamMembership, team_id: user.primary_team&.id if user.team_role.in?(%w[owner admin])

    ability.can :read, TeamInvitation, team_id: user.primary_team&.id
    ability.can :create, TeamInvitation, team_id: user.primary_team&.id if user.team_role.in?(%w[owner admin])
  end

  def apply_campaign_rules(ability, user)
    return unless FeatureFlag.enabled?(:campaigns)

    if FeatureFlag.enabled?(:workspaces)
      workspace_ids = user.accessible_workspaces.select(:id)
      ability.can :read, Campaign, workspace_id: workspace_ids
      ability.can :assign_links, Campaign, workspace_id: workspace_ids
      ability.can :unassign_links, Campaign, workspace_id: workspace_ids

      return unless user.team_role.in?(%w[owner admin])

      ability.can %i[update destroy], Campaign, workspace_id: workspace_ids
      ability.can :create, Campaign, workspace_id: workspace_ids unless user.at_campaign_limit?
    else
      ability.can :read, Campaign, user_id: user.id
      ability.can :assign_links, Campaign, user_id: user.id
      ability.can :unassign_links, Campaign, user_id: user.id

      return unless user.role.in?(%w[owner admin])

      ability.can %i[update destroy], Campaign, user_id: user.id
      ability.can :create, Campaign unless user.at_campaign_limit?
    end
  end

  def apply_team_rules(ability, user)
    return unless FeatureFlag.enabled?(:workspaces)

    ability.can :read, :team if user.primary_team.present?
    ability.can :accept, TeamInvitation if user.primary_team.present?
  end

  def apply_custom_domain_rules(ability, user)
    return unless CustomDomain.allowed_for?(user)

    ability.can :manage, CustomDomain, user_id: user.id
  end

  def apply_analytics_rules(ability, _user)
    ability.can :read, :analytics
  end
end

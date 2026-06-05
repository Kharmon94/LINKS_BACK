# frozen_string_literal: true

# Phase 2 stubs — uncomment and extend when Team / Workspace / Campaign models ship.
module AbilityTeamRoles
  module_function

  def apply_stubs(ability, user)
    _ = user

    # --- Campaign (Phase 2) ---
    # ability.can :read, Campaign, workspace: { team_id: user.team_id }
    # ability.can :create, Campaign do |campaign|
    #   user.role.in?(%w[owner admin]) && !user.at_campaign_limit?
    # end

    # --- Workspace (Phase 2) ---
    # ability.can :read, Workspace, team_id: user.team_id
    # ability.can :manage, Workspace, team_id: user.team_id if user.role == "owner"

    # --- TeamMembership (Phase 2) ---
    # ability.can :read, TeamMembership, team_id: user.team_id
    # ability.can :update, TeamMembership, team_id: user.team_id if user.role == "owner"

    # --- CustomDomain (Phase 2) ---
    # ability.can :manage, CustomDomain, user_id: user.id if FeatureFlag.enabled?(:custom_domains)

    # --- Analytics (Phase 2) ---
    # ability.can :read, :analytics if FeatureFlag.enabled?(:analytics)

    ability
  end
end

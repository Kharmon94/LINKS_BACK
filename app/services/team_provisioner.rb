# frozen_string_literal: true

module TeamProvisioner
  module_function

  def provision_for!(user)
    return if user.team_memberships.exists?

    ActiveRecord::Base.transaction do
      team = Team.create!(
        name: "#{user.name.presence || 'Personal'} Team",
        personal: true
      )
      team.team_memberships.create!(user: user, role: user.role.presence || "owner")
      workspace = team.workspaces.create!(
        name: "Personal Workspace",
        description: "Default workspace"
      )
      workspace.workspace_memberships.create!(user: user)
      user.update!(active_workspace: workspace)
    end
  end
end

# frozen_string_literal: true

class ProvisionTeamsForExistingUsers < ActiveRecord::Migration[8.0]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
    has_many :links, class_name: "MigrationLink", foreign_key: :user_id
  end

  class MigrationLink < ApplicationRecord
    self.table_name = "links"
  end

  class MigrationTeam < ApplicationRecord
    self.table_name = "teams"
  end

  class MigrationTeamMembership < ApplicationRecord
    self.table_name = "team_memberships"
  end

  class MigrationWorkspace < ApplicationRecord
    self.table_name = "workspaces"
  end

  class MigrationWorkspaceMembership < ApplicationRecord
    self.table_name = "workspace_memberships"
  end

  def up
    MigrationUser.find_each do |user|
      next if MigrationTeamMembership.exists?(user_id: user.id)

      team = MigrationTeam.create!(
        name: "#{user.name.presence || 'Personal'} Team",
        personal: true
      )
      MigrationTeamMembership.create!(
        team_id: team.id,
        user_id: user.id,
        role: user.role.presence || "owner"
      )
      workspace = MigrationWorkspace.create!(
        team_id: team.id,
        name: "Personal Workspace",
        description: "Default workspace"
      )
      MigrationWorkspaceMembership.create!(
        workspace_id: workspace.id,
        user_id: user.id
      )
      user.update!(active_workspace_id: workspace.id)
      MigrationLink.where(user_id: user.id, workspace_id: nil).update_all(workspace_id: workspace.id)
    end
  end

  def down
    MigrationLink.update_all(workspace_id: nil, custom_domain_id: nil)
    MigrationUser.update_all(active_workspace_id: nil)
    MigrationWorkspaceMembership.delete_all
    MigrationWorkspace.delete_all
    MigrationTeamMembership.delete_all
    MigrationTeam.delete_all
  end
end

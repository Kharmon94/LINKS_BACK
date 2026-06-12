# frozen_string_literal: true

class CreateWorkspaces < ActiveRecord::Migration[8.0]
  def change
    create_table :workspaces do |t|
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    create_table :workspace_memberships do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :workspace_memberships, %i[workspace_id user_id], unique: true

    add_reference :users, :active_workspace, foreign_key: { to_table: :workspaces }
  end
end

# frozen_string_literal: true

class CreateTeamsAndInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.boolean :personal, default: false, null: false
      t.timestamps
    end

    create_table :team_memberships do |t|
      t.references :team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
    end

    add_index :team_memberships, %i[team_id user_id], unique: true

    create_table :team_invitations do |t|
      t.references :team, null: false, foreign_key: true
      t.string :email, null: false
      t.string :role, null: false, default: "member"
      t.string :token, null: false
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end

    add_index :team_invitations, :token, unique: true
    add_index :team_invitations, %i[team_id email], unique: true,
              where: "accepted_at IS NULL", name: "index_pending_team_invitations_on_team_and_email"
  end
end

# frozen_string_literal: true

class AddPasswordSetAtToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :password_set_at, :datetime

    execute <<~SQL.squish
      UPDATE users SET password_set_at = created_at WHERE password_set_at IS NULL
    SQL
  end

  def down
    remove_column :users, :password_set_at
  end
end

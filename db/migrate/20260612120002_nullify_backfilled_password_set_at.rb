# frozen_string_literal: true

class NullifyBackfilledPasswordSetAt < ActiveRecord::Migration[8.0]
  def up
    User.where(provider: "google_oauth2").update_all(password_set_at: nil)

    User.where(admin: false).find_each do |user|
      next if user.password_set_at.blank? || user.created_at.blank?

      if (user.password_set_at - user.created_at).abs <= 1.second
        user.update_column(:password_set_at, nil)
      end
    end
  end

  def down
    # irreversible data cleanup
  end
end

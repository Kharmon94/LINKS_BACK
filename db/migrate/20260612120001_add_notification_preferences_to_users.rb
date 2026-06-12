# frozen_string_literal: true

class AddNotificationPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :notification_preferences, :json, null: false, default: {}
  end
end

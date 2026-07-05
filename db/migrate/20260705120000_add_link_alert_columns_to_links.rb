# frozen_string_literal: true

class AddLinkAlertColumnsToLinks < ActiveRecord::Migration[8.0]
  def change
    add_column :links, :push_alerts_enabled, :boolean, default: true, null: false
    add_column :links, :email_alerts_enabled, :boolean, default: true, null: false
  end
end

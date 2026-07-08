# frozen_string_literal: true

class AddAlertPreferencesToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :push_alerts_enabled, :boolean, default: true, null: false
    add_column :campaigns, :email_alerts_enabled, :boolean, default: false, null: false
    add_column :campaigns, :alert_interval_value, :integer, default: 1, null: false
    add_column :campaigns, :alert_interval_unit, :string, default: "weeks", null: false
    add_column :campaigns, :alert_interval_kind, :string, default: "time", null: false
  end
end

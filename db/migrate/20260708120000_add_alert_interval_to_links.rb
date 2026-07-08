# frozen_string_literal: true

class AddAlertIntervalToLinks < ActiveRecord::Migration[8.0]
  def change
    add_column :links, :alert_interval_value, :integer, default: 1, null: false
    add_column :links, :alert_interval_unit, :string, default: "weeks", null: false
  end
end

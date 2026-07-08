# frozen_string_literal: true

class AddAlertIntervalKindToLinks < ActiveRecord::Migration[8.0]
  def change
    add_column :links, :alert_interval_kind, :string, default: "time", null: false
  end
end

# frozen_string_literal: true

class ChangeEmailAlertsDefaultOnLinks < ActiveRecord::Migration[8.0]
  def change
    change_column_default :links, :email_alerts_enabled, from: true, to: false
  end
end

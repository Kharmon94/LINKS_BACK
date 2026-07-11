# frozen_string_literal: true

class AddLastAlertedToLinksAndCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :links, :last_alerted_at, :datetime
    add_column :links, :last_alerted_clicks, :integer, default: 0, null: false

    add_column :campaigns, :last_alerted_at, :datetime
    add_column :campaigns, :last_alerted_clicks, :integer, default: 0, null: false
  end
end

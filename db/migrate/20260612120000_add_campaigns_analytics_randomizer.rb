# frozen_string_literal: true

class AddCampaignsAnalyticsRandomizer < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :workspace_id
      t.timestamps
    end

    change_column_null :links, :destination_url, true

    add_column :links, :link_type, :string, default: "single", null: false unless column_exists?(:links, :link_type)
    add_column :links, :campaign_id, :integer unless column_exists?(:links, :campaign_id)
    add_column :links, :utm_source, :string unless column_exists?(:links, :utm_source)
    add_column :links, :utm_medium, :string unless column_exists?(:links, :utm_medium)
    add_column :links, :utm_campaign, :string unless column_exists?(:links, :utm_campaign)
    add_column :links, :utm_term, :string unless column_exists?(:links, :utm_term)
    add_column :links, :utm_content, :string unless column_exists?(:links, :utm_content)

    add_index :links, :campaign_id unless index_exists?(:links, :campaign_id)
    add_index :links, :link_type unless index_exists?(:links, :link_type)
    add_foreign_key :links, :campaigns unless foreign_key_exists?(:links, :campaigns)

    create_table :link_pool_entries do |t|
      t.references :link, null: false, foreign_key: true
      t.string :destination_url, null: false
      t.integer :weight, default: 1, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    create_table :click_events do |t|
      t.references :link, null: false, foreign_key: true
      t.datetime :clicked_at, null: false
      t.string :referrer
      t.text :user_agent
      t.string :device_type
      t.string :browser
      t.string :os
      t.string :country
      t.string :city
      t.string :ip_hash
      t.timestamps
    end

    add_index :click_events, :clicked_at
    add_index :click_events, %i[link_id clicked_at]
  end
end

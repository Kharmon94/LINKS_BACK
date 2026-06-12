# frozen_string_literal: true

class AddPoolAttributionToClickEvents < ActiveRecord::Migration[8.0]
  def change
    add_reference :click_events, :pool_entry, foreign_key: { to_table: :link_pool_entries }, null: true
    add_column :click_events, :destination_url, :string
  end
end

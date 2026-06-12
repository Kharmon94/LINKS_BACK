# frozen_string_literal: true

class AddTierToPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :plans, :tier, :string, null: false, default: "starter"
    add_index :plans, :tier
  end
end

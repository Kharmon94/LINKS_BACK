# frozen_string_literal: true

class CreateBillingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :billing_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_event_id
      t.string :event_type, null: false
      t.string :tier
      t.integer :amount_cents
      t.string :stripe_customer_id
      t.string :payload_summary
      t.timestamps
    end

    add_index :billing_events, :stripe_event_id, unique: true
    add_index :billing_events, :created_at

    add_column :plans, :monthly_amount_cents, :integer
  end
end

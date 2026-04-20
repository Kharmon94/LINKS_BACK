class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.string :name
      t.string :stripe_price_id_monthly
      t.string :stripe_price_id_yearly
      t.string :stripe_price_id_monthly_live
      t.string :stripe_price_id_yearly_live
      t.string :interval
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end

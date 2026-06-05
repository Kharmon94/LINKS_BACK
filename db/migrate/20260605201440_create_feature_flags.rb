class CreateFeatureFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :feature_flags do |t|
      t.string :key, null: false
      t.boolean :enabled, null: false, default: false
      t.text :description
      t.string :category, null: false, default: "product"

      t.timestamps
    end
    add_index :feature_flags, :key, unique: true
  end
end

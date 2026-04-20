class CreateLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :links do |t|
      t.references :user, null: false, foreign_key: true
      t.string :destination_url, null: false
      t.string :short_code, null: false
      t.string :name
      t.integer :clicks_count, null: false, default: 0

      t.timestamps
    end
    add_index :links, :short_code, unique: true
  end
end

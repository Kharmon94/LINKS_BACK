# frozen_string_literal: true

class CreateUserFeatureFlagOverrides < ActiveRecord::Migration[8.0]
  def change
    create_table :user_feature_flag_overrides do |t|
      t.references :user, null: false, foreign_key: true
      t.string :feature_flag_key, null: false
      t.boolean :enabled, null: false

      t.timestamps
    end

    add_index :user_feature_flag_overrides, %i[user_id feature_flag_key], unique: true,
                                                                           name: "index_user_feature_flag_overrides_on_user_and_key"
  end
end

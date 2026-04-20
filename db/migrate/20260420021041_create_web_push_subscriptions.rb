class CreateWebPushSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :web_push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.text :endpoint
      t.text :p256dh
      t.text :auth
      t.datetime :expires_at
      t.text :user_agent

      t.timestamps
    end
  end
end

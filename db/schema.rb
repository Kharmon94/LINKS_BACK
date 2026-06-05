# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_06_05_201440) do
  create_table "feature_flags", force: :cascade do |t|
    t.string "key", null: false
    t.boolean "enabled", default: false, null: false
    t.text "description"
    t.string "category", default: "product", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_feature_flags_on_key", unique: true
  end

  create_table "links", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "destination_url", null: false
    t.string "short_code", null: false
    t.string "name"
    t.integer "clicks_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["short_code"], name: "index_links_on_short_code", unique: true
    t.index ["user_id"], name: "index_links_on_user_id"
  end

  create_table "plans", force: :cascade do |t|
    t.string "name"
    t.string "stripe_price_id_monthly"
    t.string "stripe_price_id_yearly"
    t.string "stripe_price_id_monthly_live"
    t.string "stripe_price_id_yearly_live"
    t.string "interval"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name", default: "", null: false
    t.string "subscription_tier", default: "free", null: false
    t.string "role", default: "owner", null: false
    t.boolean "admin", default: false, null: false
    t.string "magic_link_token"
    t.datetime "magic_link_expires_at"
    t.string "provider"
    t.string "uid"
    t.string "stripe_customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "provider IS NOT NULL AND uid IS NOT NULL"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "web_push_subscriptions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.text "endpoint"
    t.text "p256dh"
    t.text "auth"
    t.datetime "expires_at"
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_web_push_subscriptions_on_user_id"
  end

  add_foreign_key "links", "users"
  add_foreign_key "web_push_subscriptions", "users"
end

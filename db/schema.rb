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

ActiveRecord::Schema[8.0].define(version: 2026_07_02_120000) do
  create_table "app_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
  end

  create_table "billing_events", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "stripe_event_id"
    t.string "event_type", null: false
    t.string "tier"
    t.integer "amount_cents"
    t.string "stripe_customer_id"
    t.string "payload_summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_billing_events_on_created_at"
    t.index ["stripe_event_id"], name: "index_billing_events_on_stripe_event_id", unique: true
    t.index ["user_id"], name: "index_billing_events_on_user_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "workspace_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id", null: false
    t.index ["public_id"], name: "index_campaigns_on_public_id", unique: true
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "click_events", force: :cascade do |t|
    t.integer "link_id", null: false
    t.datetime "clicked_at", null: false
    t.string "referrer"
    t.text "user_agent"
    t.string "device_type"
    t.string "browser"
    t.string "os"
    t.string "country"
    t.string "city"
    t.string "ip_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "pool_entry_id"
    t.string "destination_url"
    t.index ["clicked_at"], name: "index_click_events_on_clicked_at"
    t.index ["link_id", "clicked_at"], name: "index_click_events_on_link_id_and_clicked_at"
    t.index ["link_id"], name: "index_click_events_on_link_id"
    t.index ["pool_entry_id"], name: "index_click_events_on_pool_entry_id"
  end

  create_table "custom_domains", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "domain", null: false
    t.string "status", default: "pending", null: false
    t.boolean "is_default", default: false, null: false
    t.string "verification_token", null: false
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_custom_domains_on_domain", unique: true
    t.index ["user_id"], name: "index_custom_domains_on_user_id"
  end

  create_table "feature_flags", force: :cascade do |t|
    t.string "key", null: false
    t.boolean "enabled", default: false, null: false
    t.text "description"
    t.string "category", default: "product", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_feature_flags_on_key", unique: true
  end

  create_table "link_pool_entries", force: :cascade do |t|
    t.integer "link_id", null: false
    t.string "destination_url", null: false
    t.integer "weight", default: 1, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["link_id"], name: "index_link_pool_entries_on_link_id"
  end

  create_table "links", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "destination_url"
    t.string "short_code", null: false
    t.string "name"
    t.integer "clicks_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "workspace_id"
    t.integer "custom_domain_id"
    t.string "link_type", default: "single", null: false
    t.integer "campaign_id"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_campaign"
    t.string "utm_term"
    t.string "utm_content"
    t.string "public_id", null: false
    t.index ["campaign_id"], name: "index_links_on_campaign_id"
    t.index ["custom_domain_id"], name: "index_links_on_custom_domain_id"
    t.index ["link_type"], name: "index_links_on_link_type"
    t.index ["public_id"], name: "index_links_on_public_id", unique: true
    t.index ["short_code", "custom_domain_id"], name: "index_links_on_short_code_and_custom_domain", unique: true, where: "custom_domain_id IS NOT NULL"
    t.index ["short_code"], name: "index_links_on_short_code_platform", unique: true, where: "custom_domain_id IS NULL"
    t.index ["user_id"], name: "index_links_on_user_id"
    t.index ["workspace_id"], name: "index_links_on_workspace_id"
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
    t.string "tier", default: "starter", null: false
    t.integer "monthly_amount_cents"
    t.index ["tier"], name: "index_plans_on_tier"
  end

  create_table "team_invitations", force: :cascade do |t|
    t.integer "team_id", null: false
    t.string "email", null: false
    t.string "role", default: "member", null: false
    t.string "token", null: false
    t.integer "invited_by_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_team_invitations_on_invited_by_id"
    t.index ["team_id", "email"], name: "index_pending_team_invitations_on_team_and_email", unique: true, where: "accepted_at IS NULL"
    t.index ["team_id"], name: "index_team_invitations_on_team_id"
    t.index ["token"], name: "index_team_invitations_on_token", unique: true
  end

  create_table "team_memberships", force: :cascade do |t|
    t.integer "team_id", null: false
    t.integer "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "user_id"], name: "index_team_memberships_on_team_id_and_user_id", unique: true
    t.index ["team_id"], name: "index_team_memberships_on_team_id"
    t.index ["user_id"], name: "index_team_memberships_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "personal", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id", null: false
    t.index ["public_id"], name: "index_teams_on_public_id", unique: true
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
    t.datetime "password_set_at"
    t.integer "active_workspace_id"
    t.json "notification_preferences", default: {}, null: false
    t.string "public_id", null: false
    t.datetime "pwa_installed_at"
    t.index ["active_workspace_id"], name: "index_users_on_active_workspace_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "provider IS NOT NULL AND uid IS NOT NULL"
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
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

  create_table "workspace_memberships", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_workspace_memberships_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_workspace_memberships_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_workspace_memberships_on_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.integer "team_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id", null: false
    t.index ["public_id"], name: "index_workspaces_on_public_id", unique: true
    t.index ["team_id"], name: "index_workspaces_on_team_id"
  end

  add_foreign_key "billing_events", "users"
  add_foreign_key "campaigns", "users"
  add_foreign_key "click_events", "link_pool_entries", column: "pool_entry_id"
  add_foreign_key "click_events", "links"
  add_foreign_key "custom_domains", "users"
  add_foreign_key "link_pool_entries", "links"
  add_foreign_key "links", "campaigns"
  add_foreign_key "links", "custom_domains"
  add_foreign_key "links", "users"
  add_foreign_key "links", "workspaces"
  add_foreign_key "team_invitations", "teams"
  add_foreign_key "team_invitations", "users", column: "invited_by_id"
  add_foreign_key "team_memberships", "teams"
  add_foreign_key "team_memberships", "users"
  add_foreign_key "users", "workspaces", column: "active_workspace_id"
  add_foreign_key "web_push_subscriptions", "users"
  add_foreign_key "workspace_memberships", "users"
  add_foreign_key "workspace_memberships", "workspaces"
  add_foreign_key "workspaces", "teams"
end

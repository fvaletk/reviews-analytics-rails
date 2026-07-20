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

ActiveRecord::Schema[8.0].define(version: 2026_07_20_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "apps", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "app_store_id"
    t.string "app_store_country", default: "us"
    t.string "play_store_id"
    t.integer "created_by_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id"], name: "index_apps_on_workspace_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.bigint "report_id", null: false
    t.string "message", null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id"], name: "index_notifications_on_report_id"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
    t.index ["workspace_id"], name: "index_notifications_on_workspace_id"
  end

  create_table "pending_invitations", force: :cascade do |t|
    t.string "email", null: false
    t.bigint "workspace_id", null: false
    t.integer "role", null: false
    t.integer "invited_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email", "workspace_id"], name: "index_pending_invitations_on_email_and_workspace_id", unique: true
    t.index ["workspace_id"], name: "index_pending_invitations_on_workspace_id"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "app_id", null: false
    t.bigint "generated_by_user_id", null: false
    t.integer "status", default: 0, null: false
    t.text "failure_reason"
    t.jsonb "structured_output"
    t.integer "total_reviews_analyzed", default: 0, null: false
    t.datetime "reviews_fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "app_store_reviews_count", default: 0, null: false
    t.integer "play_store_reviews_count", default: 0, null: false
    t.integer "report_type", default: 0, null: false
    t.index ["app_id"], name: "index_reports_on_app_id"
    t.index ["generated_by_user_id"], name: "index_reports_on_generated_by_user_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "app_id", null: false
    t.integer "store", null: false
    t.string "external_id", null: false
    t.string "author"
    t.integer "rating"
    t.string "title"
    t.text "body"
    t.datetime "reviewed_at"
    t.datetime "fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id", "store", "external_id"], name: "index_reviews_on_app_id_and_store_and_external_id", unique: true
    t.index ["app_id"], name: "index_reviews_on_app_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.string "avatar_url"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  create_table "workspace_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.integer "role", null: false
    t.integer "invited_by_user_id"
    t.datetime "joined_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "workspace_id"], name: "index_workspace_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["user_id"], name: "index_workspace_memberships_on_user_id"
    t.index ["workspace_id"], name: "index_workspace_memberships_on_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
  end

  add_foreign_key "apps", "users", column: "created_by_user_id"
  add_foreign_key "apps", "workspaces"
  add_foreign_key "notifications", "reports"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "workspaces"
  add_foreign_key "pending_invitations", "workspaces"
  add_foreign_key "reports", "apps"
  add_foreign_key "reports", "users", column: "generated_by_user_id"
  add_foreign_key "reviews", "apps"
  add_foreign_key "workspace_memberships", "users"
  add_foreign_key "workspace_memberships", "workspaces"
end

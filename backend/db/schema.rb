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

ActiveRecord::Schema[8.1].define(version: 2026_08_01_181012) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "browser_images", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "tag"
    t.datetime "updated_at", null: false
    t.string "version"
  end

  create_table "browser_sessions", force: :cascade do |t|
    t.string "browser_name", default: "Chrome", null: false
    t.string "container_id"
    t.datetime "created_at", null: false
    t.datetime "end_time"
    t.datetime "start_time"
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_browser_sessions_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "repository_url"
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["team_id"], name: "index_projects_on_team_id"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.string "role", default: "developer", null: false
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["team_id"], name: "index_users_on_team_id"
  end

  add_foreign_key "browser_sessions", "users"
  add_foreign_key "projects", "teams"
  add_foreign_key "projects", "users"
  add_foreign_key "users", "teams"
end

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

ActiveRecord::Schema[8.1].define(version: 2026_08_02_040000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "artifacts", force: :cascade do |t|
    t.string "artifact_type", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.string "path", null: false
    t.bigint "size", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["job_id", "artifact_type"], name: "index_artifacts_on_job_id_and_artifact_type"
    t.index ["job_id"], name: "index_artifacts_on_job_id"
  end

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

  create_table "execution_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.string "level", default: "info", null: false
    t.text "message", null: false
    t.datetime "timestamp", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id", "timestamp"], name: "index_execution_logs_on_job_id_and_timestamp"
    t.index ["job_id"], name: "index_execution_logs_on_job_id"
  end

  create_table "github_integrations", force: :cascade do |t|
    t.string "access_token"
    t.datetime "created_at", null: false
    t.string "github_login"
    t.bigint "github_user_id"
    t.string "scope"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["github_user_id"], name: "index_github_integrations_on_github_user_id"
    t.index ["user_id"], name: "index_github_integrations_on_user_id"
  end

  create_table "github_repositories", force: :cascade do |t|
    t.string "clone_url"
    t.datetime "created_at", null: false
    t.string "default_branch"
    t.text "description"
    t.string "full_name", null: false
    t.bigint "github_integration_id", null: false
    t.bigint "github_repo_id", null: false
    t.string "html_url"
    t.boolean "private", default: false, null: false
    t.bigint "project_id", null: false
    t.string "ssh_url"
    t.datetime "updated_at", null: false
    t.index ["github_integration_id"], name: "index_github_repositories_on_github_integration_id"
    t.index ["github_repo_id"], name: "index_github_repositories_on_github_repo_id", unique: true
    t.index ["project_id"], name: "index_github_repositories_on_project_id", unique: true
  end

  create_table "github_webhook_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "delivery_id"
    t.string "event"
    t.bigint "github_webhook_id", null: false
    t.jsonb "payload"
    t.datetime "received_at"
    t.boolean "signature_valid", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_github_webhook_deliveries_on_delivery_id"
    t.index ["github_webhook_id"], name: "index_github_webhook_deliveries_on_github_webhook_id"
  end

  create_table "github_webhooks", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "events"
    t.bigint "github_repository_id", null: false
    t.bigint "github_webhook_id"
    t.datetime "last_delivery_at"
    t.string "secret"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["github_repository_id"], name: "index_github_webhooks_on_github_repository_id"
    t.index ["github_webhook_id"], name: "index_github_webhooks_on_github_webhook_id", unique: true
    t.index ["slug"], name: "index_github_webhooks_on_slug", unique: true
  end

  create_table "job_retries", force: :cascade do |t|
    t.integer "attempt", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "job_id", null: false
    t.string "reason", null: false
    t.datetime "retried_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id", "attempt"], name: "index_job_retries_on_job_id_and_attempt"
    t.index ["job_id"], name: "index_job_retries_on_job_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.integer "chunk_number", default: 1, null: false
    t.string "container_id"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.string "error_type"
    t.integer "failed_tests", default: 0, null: false
    t.datetime "finished_at"
    t.integer "passed_tests", default: 0, null: false
    t.integer "retry_count", default: 0, null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.integer "test_count", default: 0, null: false
    t.bigint "test_run_id", null: false
    t.datetime "updated_at", null: false
    t.string "worker_id"
    t.index ["container_id"], name: "index_jobs_on_container_id"
    t.index ["error_type"], name: "index_jobs_on_error_type"
    t.index ["status"], name: "index_jobs_on_status"
    t.index ["test_run_id", "chunk_number"], name: "index_jobs_on_test_run_id_and_chunk_number", unique: true
    t.index ["test_run_id"], name: "index_jobs_on_test_run_id"
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

  create_table "test_runs", force: :cascade do |t|
    t.string "branch", default: "main", null: false
    t.string "commit_sha"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "failed_jobs", default: 0, null: false
    t.integer "failed_tests", default: 0, null: false
    t.datetime "finished_at"
    t.integer "passed_tests", default: 0, null: false
    t.float "progress_percentage", default: 0.0, null: false
    t.bigint "project_id", null: false
    t.integer "queued_jobs", default: 0, null: false
    t.integer "running_jobs", default: 0, null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.bigint "test_suite_id"
    t.bigint "total_duration_ms"
    t.integer "total_jobs", default: 0, null: false
    t.integer "total_screenshots", default: 0, null: false
    t.integer "total_tests", default: 0, null: false
    t.integer "total_videos", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "created_at"], name: "index_test_runs_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_test_runs_on_project_id"
    t.index ["status"], name: "index_test_runs_on_status"
    t.index ["test_suite_id"], name: "index_test_runs_on_test_suite_id"
  end

  create_table "test_suites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "total_tests", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_test_suites_on_name", unique: true
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

  create_table "worker_heartbeats", force: :cascade do |t|
    t.float "cpu_usage"
    t.datetime "created_at", null: false
    t.bigint "current_job_id"
    t.integer "execution_count", default: 0, null: false
    t.datetime "last_seen_at"
    t.float "memory_usage"
    t.string "status", default: "idle", null: false
    t.datetime "updated_at", null: false
    t.string "worker_name", null: false
    t.index ["last_seen_at"], name: "index_worker_heartbeats_on_last_seen_at"
    t.index ["status"], name: "index_worker_heartbeats_on_status"
    t.index ["worker_name"], name: "index_worker_heartbeats_on_worker_name", unique: true
  end

  add_foreign_key "artifacts", "jobs"
  add_foreign_key "browser_sessions", "users"
  add_foreign_key "execution_logs", "jobs"
  add_foreign_key "github_integrations", "users"
  add_foreign_key "github_repositories", "github_integrations"
  add_foreign_key "github_repositories", "projects"
  add_foreign_key "github_webhook_deliveries", "github_webhooks"
  add_foreign_key "github_webhooks", "github_repositories"
  add_foreign_key "job_retries", "jobs"
  add_foreign_key "jobs", "test_runs"
  add_foreign_key "projects", "teams"
  add_foreign_key "projects", "users"
  add_foreign_key "test_runs", "projects"
  add_foreign_key "test_runs", "test_suites"
  add_foreign_key "users", "teams"
  add_foreign_key "worker_heartbeats", "jobs", column: "current_job_id"
end

class CreateBuilds < ActiveRecord::Migration[8.1]
  def change
    create_table :builds do |t|
      t.bigint :project_id, null: false
      t.bigint :pipeline_id
      t.bigint :test_run_id
      t.bigint :jenkins_build_number
      t.string :jenkins_job_name
      t.string :commit_sha
      t.string :branch
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :finished_at
      t.bigint :duration

      t.timestamps
    end

    # Idempotency: the same Jenkins job + build number must map to exactly one
    # Build (and therefore one TestRun), no matter how many times Jenkins retries.
    add_index :builds, [:project_id, :jenkins_job_name, :jenkins_build_number],
              unique: true, name: "index_builds_on_project_job_and_build_number"
    add_index :builds, :pipeline_id
    add_index :builds, :test_run_id
    add_index :builds, :status
    add_foreign_key :builds, :projects
    add_foreign_key :builds, :pipelines
    add_foreign_key :builds, :test_runs
  end
end
class CreateTestRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :test_runs do |t|
      t.references :project, null: false, foreign_key: true
      t.string :branch, null: false, default: "main"
      t.string :commit_sha, null: false
      t.string :status, null: false, default: "queued"
      t.integer :total_tests, null: false, default: 0
      t.integer :total_jobs, null: false, default: 0
      t.integer :completed_jobs, null: false, default: 0
      t.integer :failed_jobs, null: false, default: 0
      t.integer :queued_jobs, null: false, default: 0
      t.float :progress_percentage, null: false, default: 0.0
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :test_runs, [:project_id, :created_at]
    add_index :test_runs, :status
  end
end

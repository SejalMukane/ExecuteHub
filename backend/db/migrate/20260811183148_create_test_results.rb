# Week 7 — individual test outcomes parsed from Playwright's JSON report.
# The failed test is the primary debugging object: it carries the error
# message + stack trace, the browser/worker that ran it, its duration and
# retry count, and links back to the Job that produced its artifacts.
class CreateTestResults < ActiveRecord::Migration[8.1]
  def change
    create_table :test_results do |t|
      t.references :job, null: false, foreign_key: true
      t.references :test_run, null: false, foreign_key: true
      t.string :test_name, null: false
      t.string :suite_name
      t.string :status, null: false
      t.integer :duration_ms, null: false, default: 0
      t.string :browser
      t.text :error_message
      t.text :stack_trace
      t.integer :retry_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :test_results, :status
    add_index :test_results, :created_at
    add_index :test_results, %i[test_run_id status]
    add_index :test_results, %i[test_name status]
    add_index :test_results, %i[suite_name status]
  end
end

# Week 7 — one aggregated report per TestRun, produced by ResultAggregator when
# every Job is terminal (fan-in). success_rate is stored as a percentage
# (0..100) with one decimal.
class CreateTestReports < ActiveRecord::Migration[8.1]
  def change
    create_table :test_reports do |t|
      t.references :test_run, null: false, foreign_key: true, index: false
      t.integer :total_tests, null: false, default: 0
      t.integer :passed_tests, null: false, default: 0
      t.integer :failed_tests, null: false, default: 0
      t.integer :skipped_tests, null: false, default: 0
      t.integer :flaky_tests, null: false, default: 0
      t.integer :duration_ms, null: false, default: 0
      t.float :success_rate, null: false, default: 0.0
      t.datetime :generated_at, null: false

      t.timestamps
    end

    add_index :test_reports, :test_run_id, unique: true
    add_index :test_reports, :generated_at
  end
end

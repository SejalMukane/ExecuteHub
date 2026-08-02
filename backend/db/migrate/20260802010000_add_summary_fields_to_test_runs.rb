class AddSummaryFieldsToTestRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :test_runs, :passed_tests, :integer, default: 0, null: false
    add_column :test_runs, :failed_tests, :integer, default: 0, null: false
    add_column :test_runs, :total_duration_ms, :bigint
    add_column :test_runs, :total_screenshots, :integer, default: 0, null: false
    add_column :test_runs, :total_videos, :integer, default: 0, null: false
  end
end

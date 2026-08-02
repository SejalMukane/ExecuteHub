class AddRunningJobsToTestRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :test_runs, :running_jobs, :integer, default: 0, null: false
  end
end

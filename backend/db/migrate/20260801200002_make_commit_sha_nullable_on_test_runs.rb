class MakeCommitShaNullableOnTestRuns < ActiveRecord::Migration[8.1]
  def change
    change_column_null :test_runs, :commit_sha, true
  end
end

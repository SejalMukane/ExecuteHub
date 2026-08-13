class AddPipelineToTestRuns < ActiveRecord::Migration[8.1]
  def change
    # Links a TestRun to the CI pipeline that triggered it (nullable so manual
    # runs keep working untouched).
    add_reference :test_runs, :pipeline, null: true, foreign_key: true
  end
end
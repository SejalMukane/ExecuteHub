FactoryBot.define do
  factory :artifact do
    association :job
    artifact_type { "screenshot" }
    path { "job_01/artifacts/test.png" }
    sequence(:s3_key) { |n| "executehub/projects/project_1/test_runs/run_1/jobs/job_1/screenshots/20260811_000000_abcd#{format('%04d', n)}_test.png" }
    size { 1024 }
    status { "pending" }
    # file_name is derived from path.basename by the model when not provided.
    # test_run_id is auto-assigned from job.test_run_id by the model.
  end
end

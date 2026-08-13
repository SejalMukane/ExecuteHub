FactoryBot.define do
  factory :test_run do
    association :project
    branch { "main" }
    commit_sha { SecureRandom.hex(20) }
    total_tests { 100 }
    status { "queued" }
    total_jobs { 0 }
    completed_jobs { 0 }
    failed_jobs { 0 }
    queued_jobs { 0 }
    progress_percentage { 0.0 }

    trait :completed do
      status { "completed" }
      finished_at { Time.current }
      progress_percentage { 100.0 }
      completed_jobs { 1 }
    end

    trait :failed do
      status { "failed" }
      finished_at { Time.current }
      progress_percentage { 100.0 }
    end
  end
end

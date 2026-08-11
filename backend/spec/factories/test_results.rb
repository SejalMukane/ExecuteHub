FactoryBot.define do
  factory :test_result do
    association :job
    association :test_run
    sequence(:test_name) { |n| "test number #{n}" }
    suite_name { "example.spec.ts" }
    status { "passed" }
    duration_ms { 500 }
    browser { "Chrome" }
    retry_count { 0 }
  end
end

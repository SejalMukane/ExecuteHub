FactoryBot.define do
  factory :test_report do
    association :test_run
    total_tests { 100 }
    passed_tests { 95 }
    failed_tests { 3 }
    skipped_tests { 2 }
    flaky_tests { 0 }
    duration_ms { 30_000 }
    success_rate { 95.0 }
    generated_at { Time.current }
  end
end

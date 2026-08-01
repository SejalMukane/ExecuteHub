FactoryBot.define do
  factory :test_suite do
    sequence(:name) { |n| "Test Suite #{n}" }
    description { "A collection of tests" }
    total_tests { 100 }
  end
end

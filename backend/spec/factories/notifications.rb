FactoryBot.define do
  factory :notification do
    association :project
    title { "Test run finished" }
    description { "100% of tests passed" }
    category { "test_run" }
    read { false }
  end
end
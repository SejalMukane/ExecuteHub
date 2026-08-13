FactoryBot.define do
  factory :deployment_gate do
    association :project
    association :test_run
    association :pipeline
    status { "pending" }
    requires_approval { true }
  end
end
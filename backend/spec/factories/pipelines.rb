FactoryBot.define do
  factory :pipeline do
    association :project
    name { "ExecuteHub-App" }
    provider { "jenkins" }
    status { "pending" }
    branch { "main" }
    commit_sha { SecureRandom.hex(20) }
    triggered_by { "jenkins" }
    sequence(:ci_key) { |n| "jenkins:ExecuteHub-App:#{n}" }
  end
end
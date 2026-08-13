FactoryBot.define do
  factory :build do
    association :project
    association :pipeline
    association :test_run
    sequence(:jenkins_build_number) { |n| 100 + n }
    jenkins_job_name { "ExecuteHub-App" }
    branch { "main" }
    commit_sha { SecureRandom.hex(20) }
    status { "pending" }
  end
end
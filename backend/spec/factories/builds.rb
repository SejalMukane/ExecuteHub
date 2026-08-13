FactoryBot.define do
  factory :build do
    association :project
    association :pipeline
    association :test_run
    jenkins_build_number { 42 }
    jenkins_job_name { "ExecuteHub-App" }
    branch { "main" }
    commit_sha { SecureRandom.hex(20) }
    status { "pending" }
  end
end
FactoryBot.define do
  factory :artifact do
    association :job
    artifact_type { "screenshot" }
    path { "job_01/artifacts/test.png" }
    size { 1024 }
  end
end

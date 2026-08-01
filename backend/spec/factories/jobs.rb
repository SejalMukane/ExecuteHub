FactoryBot.define do
  factory :job do
    association :test_run
    sequence(:chunk_number) { |n| n }
    test_count { 20 }
    status { "queued" }
    retry_count { 0 }
  end
end

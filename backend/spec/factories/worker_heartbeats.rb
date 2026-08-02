FactoryBot.define do
  factory :worker_heartbeat do
    sequence(:worker_name) { |n| format("Worker-%02d", n) }
    status { "idle" }
    last_seen_at { Time.current }
    execution_count { 0 }
  end
end

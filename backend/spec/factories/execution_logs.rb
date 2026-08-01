FactoryBot.define do
  factory :execution_log do
    association :job
    timestamp { Time.current }
    level { "info" }
    message { "execution log line" }
  end
end

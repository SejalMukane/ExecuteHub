FactoryBot.define do
  factory :ci_api_token do
    association :project
    name { "Jenkins" }
    token_prefix { "eh_12345678" }
    sequence(:token_digest) { |n| Digest::SHA256.hexdigest("token-#{n}") }
  end
end
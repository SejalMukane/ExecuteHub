FactoryBot.define do
  factory :project do
    name { "Test Project" }
    association :user
    association :team
  end
end

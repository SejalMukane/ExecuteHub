class Project < ApplicationRecord
  belongs_to :user
  belongs_to :team

  has_one :github_repository, dependent: :destroy

  has_many :test_runs, dependent: :destroy
  has_many :pipelines, dependent: :destroy
  has_many :builds, dependent: :destroy
  has_many :deployment_gates, dependent: :destroy
  has_many :ci_api_tokens, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :name, presence: true

  # Release-gating configuration consumed by ReleaseGateService, e.g.
  #   { "minimum_success_rate" => 95, "required_suites" => ["smoke"] }
  # Falls back to the global defaults when a key is absent.
  def release_policy
    (super || {}).with_indifferent_access
  end
end

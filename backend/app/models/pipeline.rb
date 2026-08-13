# Pipeline is the CI/CD pipeline that triggered one or more test runs — e.g.
# a single Jenkins build that calls ExecuteHub. It ties together the Jenkins
# Build(s), the TestRuns they produced, and the DeploymentGate that protects
# the release.
class Pipeline < ApplicationRecord
  belongs_to :project

  has_many :builds, dependent: :destroy
  has_many :test_runs, dependent: :destroy
  has_one :deployment_gate, dependent: :destroy

  enum :provider, {
    jenkins: "jenkins",
    github_actions: "github_actions"
  }, default: :jenkins

  enum :status, {
    pending: "pending",
    running: "running",
    passed: "passed",
    failed: "failed",
    cancelled: "cancelled",
    blocked: "blocked"
  }, default: :pending

  validates :name, presence: true
  validates :ci_key, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_project, ->(project) { where(project: project) }

  # A pipeline is terminal once it can no longer change state.
  def terminal?
    %w[passed failed cancelled blocked].include?(status)
  end
end
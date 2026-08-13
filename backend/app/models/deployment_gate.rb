# DeploymentGate is the release gate protecting a pipeline. It reflects whether
# the test evidence for the pipeline is good enough to deploy:
#
#   pending   -> evaluation in progress or waiting for a human
#   approved  -> ReleaseGateService approved (possibly after manual approval)
#   blocked   -> a rule failed (critical tests, success rate, ...) or a human rejected
#   expired   -> the gate's tests went stale and it must be re-evaluated
#
# For this phase the gate only decides the deployment *state*; actually
# deploying to AWS/Kubernetes is out of scope.
class DeploymentGate < ApplicationRecord
  belongs_to :project
  belongs_to :test_run, optional: true
  belongs_to :pipeline

  enum :status, {
    pending: "pending",
    approved: "approved",
    blocked: "blocked",
    expired: "expired"
  }, default: :pending

  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_project, ->(project) { where(project: project) }

  def approved?
    status == "approved"
  end

  def blocked?
    status == "blocked"
  end

  def approve!
    update!(status: :approved, decided_at: Time.current, reason: nil)
  end

  def block!(reason = nil)
    update!(status: :blocked, decided_at: Time.current, reason: reason)
  end
end
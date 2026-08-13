# Build tracks a single CI provider build (by default a Jenkins build) that is
# currently executing against ExecuteHub. It records the provider identity
# (job name + build number) needed to correlate callbacks/polls with the
# correct TestRun, and captures the commit/result for the pipeline timeline.
class Build < ApplicationRecord
  belongs_to :project
  belongs_to :pipeline, optional: true
  belongs_to :test_run, optional: true

  enum :status, {
    pending: "pending",
    running: "running",
    passed: "passed",
    failed: "failed",
    cancelled: "cancelled",
    error: "error"
  }, default: :pending

  validates :jenkins_build_number, presence: true
  validates :jenkins_job_name, presence: true
  validates :branch, presence: true
  validates :status, presence: true

  validates :jenkins_build_number,
            uniqueness: { scope: [:project_id, :jenkins_job_name],
                          message: "already exists for this job" }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_project, ->(project) { where(project: project) }

  # Wall-clock duration in seconds (started -> finished). `duration` is stored
  # in milliseconds.
  def duration_seconds
    return unless duration

    (duration.to_f / 1000).round(2)
  end

  def terminal?
    %w[passed failed cancelled error].include?(status)
  end

  def mark_running!
    update!(status: :running, started_at: started_at || Time.current)
  end

  def finish!(new_status)
    finished = Time.current
    ms = started_at ? ((finished - started_at) * 1000).to_i : nil
    update!(status: new_status, finished_at: finished, duration: ms)
  end
end
class Job < ApplicationRecord
  belongs_to :test_run

  has_many :execution_logs, dependent: :destroy
  has_many :artifacts, dependent: :destroy

  enum :status, {
    queued: "queued",
    running: "running",
    uploading_artifacts: "uploading_artifacts",
    completed: "completed",
    failed: "failed",
    retrying: "retrying"
  }, default: :queued

  validates :chunk_number, presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  validates :test_count, presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true
  validates :retry_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :passed_tests, :failed_tests,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :recent, -> { order(chunk_number: :asc) }

  # Mark a job as picked up by a worker and begin execution.
  def mark_running!
    update!(status: :running, started_at: Time.current, worker_id: worker_identity)
  end

  # Mark a job as uploading its execution artifacts (between run + terminal).
  def mark_uploading_artifacts!
    update!(status: :uploading_artifacts)
  end

  # Mark a job as finished successfully.
  def mark_completed!
    update!(status: :completed, finished_at: Time.current)
  end

  # Mark a job as failed (terminal state).
  def mark_failed!
    update!(status: :failed, finished_at: Time.current)
  end

  # Record that a worker retried this job.
  def mark_retrying!
    update!(status: :retrying, retry_count: retry_count + 1)
  end

  # Wall-clock execution duration in seconds (started -> finished).
  def duration_seconds
    return unless started_at && finished_at

    (finished_at - started_at).round(2)
  end

  private

  # Identity of the Sidekiq process running the job.
  def worker_identity
    "sidekiq:#{Process.pid}"
  end
end

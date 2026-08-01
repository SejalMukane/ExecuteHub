class Job < ApplicationRecord
  belongs_to :test_run

  enum :status, {
    queued: "queued",
    running: "running",
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

  scope :recent, -> { order(chunk_number: :asc) }

  # Mark a job as picked up by a worker.
  def mark_running!
    update!(status: :running, started_at: Time.current, worker_id: worker_identity)
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

  private

  # Identity of the Sidekiq process running the job (no real workers yet).
  def worker_identity
    "sidekiq:#{Process.pid}"
  end
end

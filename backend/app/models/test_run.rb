class TestRun < ApplicationRecord
  belongs_to :project
  belongs_to :test_suite, optional: true
  has_many :jobs, dependent: :destroy

  enum :status, {
    queued: "queued",
    scheduling: "scheduling",
    running: "running",
    completed: "completed",
    failed: "failed",
    cancelled: "cancelled"
  }, default: :queued

  validates :branch, presence: true
  validates :total_tests, presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  validates :total_jobs, :completed_jobs, :failed_jobs, :queued_jobs, :running_jobs,
            :passed_tests, :failed_tests, :total_screenshots, :total_videos,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_duration_ms,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :progress_percentage,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_project, ->(project) { where(project: project) }

  # Live counters for the distributed execution dashboard. The four job buckets
  # partition the run's jobs (total = queued + running + completed + failed),
  # so a dashboard can render them without re-querying every Job.
  def progress_snapshot
    {
      id: id,
      status: status,
      total_tests: total_tests,
      total_jobs: total_jobs,
      queued_jobs: queued_jobs,
      running_jobs: running_jobs,
      completed_jobs: completed_jobs,
      failed_jobs: failed_jobs,
      passed_tests: passed_tests,
      failed_tests: failed_tests,
      total_screenshots: total_screenshots,
      total_videos: total_videos,
      total_duration_ms: total_duration_ms,
      progress_percentage: progress_percentage,
      started_at: started_at,
      finished_at: finished_at
    }
  end
end

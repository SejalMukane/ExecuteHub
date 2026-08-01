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
  validates :total_jobs, :completed_jobs, :failed_jobs, :queued_jobs,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :progress_percentage,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_project, ->(project) { where(project: project) }
end

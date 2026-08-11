# TestResult is the outcome of a single test executed by a Job (parsed from
# Playwright's JSON report). The failed test is the primary debugging object:
# it carries the error message + stack trace, browser, worker, duration and
# retry count, and links back to the Job whose artifacts (screenshot, video,
# trace, logs) make up the failure's evidence.
class TestResult < ApplicationRecord
  belongs_to :job
  belongs_to :test_run

  STATUSES = %w[passed failed skipped flaky].freeze

  validates :test_name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :duration_ms,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :retry_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :passed, -> { where(status: "passed") }
  scope :failed, -> { where(status: "failed") }
  scope :skipped, -> { where(status: "skipped") }
  scope :flaky, -> { where(status: "flaky") }
  scope :chronological, -> { order(started_at: :asc, id: :asc) }

  def failed?
    status == "failed"
  end

  def passed?
    status == "passed"
  end
end

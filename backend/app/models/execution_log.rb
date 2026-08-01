# ExecutionLog is an append-only audit of what happened during a Job's
# execution (container lifecycle, Playwright output, artifact upload). Logs are
# written while execution happens and exposed through the Jobs API for the
# frontend's live log stream.
class ExecutionLog < ApplicationRecord
  belongs_to :job

  LEVELS = %w[info warn error].freeze

  validates :timestamp, presence: true
  validates :level, presence: true, inclusion: { in: LEVELS }
  validates :message, presence: true

  before_validation :set_timestamp, if: -> { timestamp.blank? }

  scope :chronological, -> { order(timestamp: :asc, id: :asc) }
  scope :reverse_chronological, -> { order(timestamp: :desc, id: :desc) }

  private

  def set_timestamp
    self.timestamp = Time.current
  end
end

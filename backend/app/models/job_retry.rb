# JobRetry records one entry in a Job's retry history: which attempt failed,
# why it was retried, and when. Kept append-only so the full retry story of a
# Job is always available.
class JobRetry < ApplicationRecord
  belongs_to :job

  validates :attempt, presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  validates :reason, presence: true
  validates :retried_at, presence: true

  scope :chronological, -> { order(retried_at: :asc, id: :asc) }
end

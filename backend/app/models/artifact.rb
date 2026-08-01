# Artifact describes a file produced by a Job's Playwright execution
# (screenshot / video / trace). Only local filesystem paths are stored for now —
# no S3. The path is relative to ArtifactStore.root so records stay portable.
class Artifact < ApplicationRecord
  belongs_to :job

  TYPES = %w[screenshot video trace].freeze

  validates :artifact_type, presence: true, inclusion: { in: TYPES }
  validates :path, presence: true
  validates :size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :screenshots, -> { where(artifact_type: "screenshot") }
  scope :videos, -> { where(artifact_type: "video") }
  scope :traces, -> { where(artifact_type: "trace") }
end

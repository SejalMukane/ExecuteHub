# Artifact describes a file produced by a Job's Playwright execution
# (screenshot / video / trace / log / report).
#
# Local vs remote (Week 7):
#   - path      -> filesystem path relative to ArtifactStore.root (local copy,
#                  always kept so failed uploads can be retried)
#   - s3_key    -> logical key in remote storage (S3 or the local store)
#   - status    -> pending / uploading / uploaded / failed upload lifecycle
#   - checksum  -> hex digest of the uploaded bytes (computed on upload)
#
# PostgreSQL only stores metadata — the bytes live in S3 (or the local
# development store). Storage implementation lives in S3StorageService /
# LocalStorageService and is hidden behind StorageService.adapter.
class Artifact < ApplicationRecord
  belongs_to :job
  belongs_to :test_run, optional: true

  TYPES = %w[screenshot video trace log report].freeze
  STATUSES = %w[pending uploading uploaded failed].freeze

  validates :artifact_type, presence: true, inclusion: { in: TYPES }
  validates :path, presence: true
  validates :file_name, presence: true, allow_nil: true
  validates :s3_key, presence: true, allow_nil: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :test_run_id, presence: true

  before_validation :assign_test_run
  before_validation :assign_file_name

  scope :screenshots, -> { where(artifact_type: "screenshot") }
  scope :videos, -> { where(artifact_type: "video") }
  scope :traces, -> { where(artifact_type: "trace") }
  scope :logs, -> { where(artifact_type: "log") }
  scope :reports, -> { where(artifact_type: "report") }
  scope :uploaded, -> { where(status: "uploaded") }
  scope :failed, -> { where(status: "failed") }
  scope :pending, -> { where(status: %w[pending uploading failed]) }

  def upload!
    mark_uploading!
    local_path = ArtifactStore.resolve(path)
    StorageService.adapter.upload(local_path, s3_key, content_type: content_type)
    update!(status: :uploaded, checksum: ArtifactUploader.checksum(local_path), size: File.size?(local_path).to_i)
    DashboardEventService.artifact_uploaded(self)
    true
  rescue StandardError => e
    mark_failed!
    Rails.logger.error("[Artifact] Upload failed for ##{id} (#{s3_key}): #{e.class}: #{e.message}")
    DashboardEventService.artifact_failed(self, e.message)
    false
  end

  def mark_uploading!
    update!(status: :uploading)
  end

  def mark_failed!
    update!(status: :failed)
  end

  # Alias matching the spec's `file_size` field name; column stays `size`.
  def file_size
    self[:size]
  end

  def file_size=(value)
    self[:size] = value
  end

  def uploaded?
    status == "uploaded"
  end

  private

  def assign_test_run
    self.test_run_id ||= job&.test_run_id
  end

  def assign_file_name
    self.file_name ||= path.to_s.split("/").last if path.present?
  end
end

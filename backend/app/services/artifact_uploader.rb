# ArtifactUploader owns the artifact persistence + upload pipeline. It is the
# ONLY place (besides the model lifecycle) that turns a locally collected
# artifact file into a remote object:
#
#   WorkerExecutor collects files locally
#     -> persist_artifacts creates pending Artifact records + enqueues uploads
#     -> ArtifactUploadJob calls upload(artifact) per record
#     -> StorageService.adapter (S3 or local) stores the bytes
#     -> Artifact record flips pending -> uploading -> uploaded (+checksum)
#
# The worker never blocks on S3: persist_artifacts only writes records + queues
# background jobs, and uploads happen asynchronously. A failed upload marks the
# record `failed`, preserves the local file (path is kept on the record) and
# can be retried later.
class ArtifactUploader
  ARTIFACT_TYPES = %w[screenshot video trace log report].freeze

  # PlaywrightOutputParser emits plural summary keys (screenshots:, videos:,
  # traces:) and WorkerExecutor appends logs: + reports:. This maps each
  # artifact type to the summary key that carries its collected file paths.
  SUMMARY_KEYS = {
    "screenshot" => :screenshots,
    "video" => :videos,
    "trace" => :traces,
    "log" => :logs,
    "report" => :reports
  }.freeze

  class << self
    # Creates pending Artifact records for every local artifact file a Job
    # collected, then enqueues one ArtifactUploadJob per artifact. Returns the
    # number of artifacts persisted.
    def persist_artifacts(job, summary)
      new(job, summary).persist_artifacts
    end

    # Uploads one artifact record to remote storage (called by the job).
    # Returns true on success, false on failure (status left as failed).
    def upload(artifact)
      artifact.upload!
    end

    # SHA-256 hex digest of a local file — used to verify upload integrity and
    # exposed on the Artifact record.
    def checksum(path)
      Digest::SHA256.file(path).hexdigest
    end
  end

  def initialize(job, summary)
    @job = job
    @summary = summary.symbolize_keys
  end

  def persist_artifacts
    records = []
    ARTIFACT_TYPES.each do |type|
      Array(@summary[SUMMARY_KEYS.fetch(type)]).compact.each do |local_path|
        records << artifact_attributes(type, Pathname.new(local_path))
      end
    end

    return 0 if records.empty?

    persisted = @job.artifacts.create!(records)
    enqueue_uploads(Array(persisted))
    persisted.size
  end

  private

  def artifact_attributes(type, path)
    {
      artifact_type: type,
      path: ArtifactStore.relative(path),
      file_name: path.basename.to_s,
      size: File.size?(path).to_i,
      content_type: content_type_for(type),
      s3_key: ArtifactKeyBuilder.build(
        job: @job,
        artifact_type: type,
        original_name: path.basename.to_s
      ),
      status: :pending
    }
  end

  def content_type_for(type)
    case type
    when "screenshot" then "image/png"
    when "video" then "video/webm"
    when "trace" then "application/zip"
    when "log" then "text/plain"
    when "report" then "application/json"
    else "application/octet-stream"
    end
  end

  # Queue the uploads. If Redis is unavailable the records stay `pending` and
  # can be retried — a queue hiccup must not fail the whole execution.
  def enqueue_uploads(artifacts)
    artifacts.each do |artifact|
      ArtifactUploadJob.perform_async(artifact.id)
    end
  rescue StandardError => e
    Rails.logger.warn("[ArtifactUploader] Failed to enqueue uploads: #{e.class}: #{e.message}")
  end
end

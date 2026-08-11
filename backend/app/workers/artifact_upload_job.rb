# ArtifactUploadJob uploads a single Artifact to remote storage in the
# background (Part 6). WorkerExecutor enqueues one of these per artifact so the
# Playwright execution worker is never blocked on S3.
#
# Upload failures are caught inside Artifact#upload!, which flips the record to
# `failed` and preserves the local file, so this job never raises and never
# wastes a Sidekiq retry — the record can be retried explicitly via
# POST /artifacts/:id/retry.
class ArtifactUploadJob
  include Sidekiq::Worker

  sidekiq_options queue: "artifacts", retry: false, backtrace: true

  def perform(artifact_id)
    artifact = Artifact.find_by(id: artifact_id)
    if artifact.nil?
      Rails.logger.warn("[ArtifactUploadJob] Artifact ##{artifact_id} not found — skipping.")
      return
    end

    Rails.logger.info("[ArtifactUploadJob] Uploading #{artifact.artifact_type} ##{artifact.id} (#{artifact.s3_key})")
    ArtifactUploader.upload(artifact)
  end
end

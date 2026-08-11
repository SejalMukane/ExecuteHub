# ArtifactCleanupJob implements artifact retention (Part 18). Artifacts older
# than ARTIFACT_RETENTION_DAYS (default 30) are removed from remote storage and
# their database records deleted. Nothing is deleted immediately — retention is
# enforced by this periodic sweep.
#
# Like HeartbeatWorker it self-reschedules its next pass, so no cron/scheduler
# gem is required. A Redis SETNX lock prevents overlapping passes.
class ArtifactCleanupJob
  include Sidekiq::Worker

  sidekiq_options queue: "default", retry: false, backtrace: true

  LOCK_KEY = "executehub:artifact_cleanup_lock".freeze
  INTERVAL_DAYS = 1

  def perform
    schedule_next_pass
    return unless acquire_lock

    begin
      cleanup_expired_artifacts
    ensure
      release_lock
    end
  end

  private

  def schedule_next_pass
    ArtifactCleanupJob.perform_in(INTERVAL_DAYS.days)
  end

  def cleanup_expired_artifacts
    cutoff = retention_days.days.ago
    expired = Artifact.where(status: "uploaded").where(created_at: ..cutoff)

    total = expired.count
    deleted = 0
    expired.find_each do |artifact|
      delete_artifact(artifact)
      deleted += 1
    rescue StandardError => e
      Rails.logger.warn("[ArtifactCleanupJob] Failed to delete artifact ##{artifact.id}: #{e.message}")
    end

    Rails.logger.info("[ArtifactCleanupJob] Cleanup complete: #{deleted}/#{total} expired artifacts removed")
    deleted
  end

  def delete_artifact(artifact)
    StorageService.adapter.delete(artifact.s3_key)
    artifact.destroy!
  end

  def retention_days
    ENV.fetch("ARTIFACT_RETENTION_DAYS") { Rails.configuration.executehub.fetch("artifact_retention_days", 30).to_s }.to_i
  end

  def acquire_lock
    Sidekiq.redis do |conn|
      conn.set(LOCK_KEY, "1", nx: true, ex: INTERVAL_DAYS * 86_400 - 60)
    end
  end

  def release_lock
    Sidekiq.redis do |conn|
      conn.del(LOCK_KEY)
    end
  rescue StandardError => e
    Rails.logger.warn("[ArtifactCleanupJob] Failed to release lock: #{e.message}")
  end
end

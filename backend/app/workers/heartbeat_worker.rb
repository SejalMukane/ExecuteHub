# HeartbeatWorker is the pool's heartbeat driver. It runs every
# heartbeat_interval_seconds (default 5s), ensuring the logical worker pool
# exists, refreshing every worker's heartbeat (last_seen_at), and flipping any
# worker whose heartbeat is too old to Offline.
#
# It self-reschedules the next pass so no cron / scheduler gem is required.
# A Redis SETNX lock (short TTL) guarantees only one instance beats per pass,
# even with multiple Sidekiq processes.
class HeartbeatWorker
  include Sidekiq::Worker

  sidekiq_options queue: "default", retry: false, backtrace: true

  LOCK_KEY = "executehub:heartbeat_lock".freeze

  def perform
    # Schedule the next pass FIRST so the chain survives every run — including
    # passes that skip the lock because another pass is mid-flight.
    schedule_next_pass

    return unless acquire_lock

    begin
      ensure_pool
      LoadBalancer.recover_orphans!
      revive_offline_workers
      beat_all_workers
      offline = HeartbeatService.mark_stale_workers_offline!
      Rails.logger.info("[HeartbeatWorker] Pass complete (#{offline} workers went offline)")
      DashboardEventService.broadcast_metrics
    ensure
      release_lock
    end
  end

  private

  def schedule_next_pass
    HeartbeatWorker.perform_in(HeartbeatService.interval_seconds)
  end

  # Register Worker-01..Worker-N so the pool always matches the configured size.
  def ensure_pool
    pool_size.times do |i|
      WorkerHeartbeat.find_or_create_by!(worker_name: format("Worker-%02d", i + 1))
    end
  end

  # Re-register any Offline pool worker back to Idle so the pool self-heals
  # after a restart or a stale blip. Orphans are recovered first so revival
  # never abandons a Job that was still in flight on the dead worker.
  def revive_offline_workers
    pool_size.times do |i|
      name = format("Worker-%02d", i + 1)
      WorkerRegistry.register!(name) if WorkerRegistry.offline?(name)
    end
  end

  def pool_size
    Rails.configuration.executehub.fetch("worker_pool_size", 5).to_i
  end

  # Refresh every healthy (non-offline + not yet stale) worker's last_seen_at,
  # preserving its status. Stale workers are deliberately NOT beaten so the
  # stale-offline check catches them (crashed / disconnected workers).
  def beat_all_workers
    threshold = WorkerHeartbeat.stale_after.seconds.ago
    WorkerHeartbeat.active.where("last_seen_at IS NULL OR last_seen_at >= ?", threshold).each do |worker|
      HeartbeatService.beat(
        worker.worker_name,
        status: worker.status,
        current_job_id: worker.current_job_id,
        cpu_usage: placeholder_cpu(worker),
        memory_usage: placeholder_memory(worker)
      )
    end
  end

  # Placeholder metrics until real host metrics are wired up. Busy workers
  # report higher load than idle ones.
  def placeholder_cpu(worker)
    worker.busy? ? rand(40.0..95.0).round(1) : rand(2.0..25.0).round(1)
  end

  def placeholder_memory(worker)
    worker.busy? ? rand(30.0..80.0).round(1) : rand(8.0..30.0).round(1)
  end

  def acquire_lock
    Sidekiq.redis do |conn|
      conn.set(LOCK_KEY, "1", nx: true, ex: HeartbeatService.interval_seconds - 1)
    end
  end

  def release_lock
    Sidekiq.redis do |conn|
      conn.del(LOCK_KEY)
    end
  rescue StandardError => e
    Rails.logger.warn("[HeartbeatWorker] Failed to release lock: #{e.message}")
  end
end

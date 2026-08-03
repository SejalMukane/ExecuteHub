# HeartbeatService owns the health of the worker pool:
#
#   - #beat            upserts a worker's heartbeat (last_seen_at refreshed)
#   - #mark_stale_workers_offline!  flips any worker whose heartbeat is older
#                      than heartbeat_stale_seconds to Offline
#
# It is driven by HeartbeatWorker, which runs every heartbeat_interval_seconds
# (default 5s). A worker that stops beating (crash, disconnect, Redis blip) is
# automatically declared Offline after 15s, which lets the rest of the system
# treat it as unavailable and re-route its jobs.
class HeartbeatService
  def self.beat(worker_name, status: "idle", current_job_id: nil, cpu_usage: nil, memory_usage: nil)
    new.beat(worker_name, status: status, current_job_id: current_job_id,
                          cpu_usage: cpu_usage, memory_usage: memory_usage)
  end

  def self.mark_stale_workers_offline!
    new.mark_stale_workers_offline!
  end

  # Interval between heartbeat passes (config-driven default 5s).
  def self.interval_seconds
    Rails.configuration.executehub.fetch("heartbeat_interval_seconds", 5).to_i
  end

  def beat(worker_name, status:, current_job_id:, cpu_usage:, memory_usage:)
    worker = WorkerHeartbeat.find_or_initialize_by(worker_name: worker_name)
    worker.assign_attributes(
      status: status,
      current_job_id: current_job_id,
      cpu_usage: cpu_usage,
      memory_usage: memory_usage,
      last_seen_at: Time.current
    )
    worker.save!
    DashboardEventService.worker_heartbeat(worker)
    worker
  end

  # Returns the number of workers that just went offline.
  def mark_stale_workers_offline!
    count = 0
    WorkerHeartbeat.active.stale.each do |worker|
      worker.mark_offline!
      DashboardEventService.worker_offline(worker)
      count += 1
    end
    count
  end
end

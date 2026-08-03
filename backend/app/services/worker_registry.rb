# WorkerRegistry is the central registry of every logical worker in the pool.
# It is the single place that decides which workers exist, which are claimable,
# and who is running what:
#
#   - #register!           upserts a worker as Idle + healthy (revives Offline)
#   - #claim_available!    atomically claims one Idle worker for a Job (-> Busy)
#   - #claim!              explicitly claims a named worker (raises if Offline)
#   - #release!            releases a worker back to Idle (-> bumps execution count)
#   - #available           Idle workers eligible for a new Job
#   - #counts              dashboard summary (total/idle/busy/offline)
#
# The registry stays decoupled from Docker / Sidekiq: it only reasons about
# WorkerHeartbeat records, so it works identically whether workers are local
# Docker containers or remote machines.
class WorkerRegistry
  class WorkerUnavailableError < StandardError; end

  class << self
    # Register a worker into the pool as Idle and healthy. Re-registering an
    # existing worker (e.g. after a Sidekiq restart) revives it from Offline.
    def register!(worker_name, cpu_usage: nil, memory_usage: nil)
      worker = WorkerHeartbeat.find_or_initialize_by(worker_name: worker_name)
      worker.assign_attributes(
        status: "idle",
        current_job: nil,
        last_seen_at: Time.current,
        cpu_usage: cpu_usage,
        memory_usage: memory_usage
      )
      worker.save!
      DashboardEventService.worker_registered(worker) if worker.previously_new_record?
      DashboardEventService.worker_online(worker)
      worker
    end

    # Atomically claim the next available (Idle) worker for the given Job.
    # FOR UPDATE SKIP LOCKED prevents two dispatches from grabbing the same
    # worker. Returns the claimed WorkerHeartbeat, or nil when every worker is
    # busy/offline.
    def claim_available!(job)
      worker = WorkerHeartbeat.available.lock("FOR UPDATE SKIP LOCKED").first
      return nil unless worker

      worker.mark_busy!(job)
      worker
    end

    # Claim a specific named worker. Raises WorkerUnavailableError if that
    # worker is not Idle and healthy (Offline or Busy).
    def claim!(worker_name, job)
      worker = WorkerHeartbeat.find_by!(worker_name: worker_name)
      unless worker.idle? && worker.healthy?
        raise WorkerUnavailableError, "#{worker_name} is #{worker.status} and cannot be claimed"
      end

      worker.mark_busy!(job)
      worker
    end

    # Release a worker back to Idle, clearing its current job and recording that
    # it finished an execution. Accepts a WorkerHeartbeat or a worker name.
    def release!(worker)
      worker = WorkerHeartbeat.find_by(worker_name: worker) if worker.is_a?(String)
      return nil unless worker

      worker.increment!(:execution_count)
      worker.mark_idle!
      worker
    end

    # Workers currently eligible to pick up a new Job.
    def available
      WorkerHeartbeat.available.order(:worker_name)
    end

    def offline?(worker_name)
      WorkerHeartbeat.exists?(worker_name: worker_name, status: :offline)
    end

    # Pool summary for dashboards and health endpoints.
    def counts
      {
        total: WorkerHeartbeat.count,
        idle: WorkerHeartbeat.idle.count,
        busy: WorkerHeartbeat.busy.count,
        offline: WorkerHeartbeat.offline.count
      }
    end
  end
end

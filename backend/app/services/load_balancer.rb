# LoadBalancer is the distributed executor's traffic cop. It decides which
# worker runs which Job, waits politely when the pool is saturated, and recycles
# Jobs that were abandoned when a worker died:
#
#   - #claim!           assign a Job to the next available (Idle) worker
#   - #requeue!         put a Job back on the queue when every worker is busy
#   - #recover_orphans!  re-dispatch Jobs whose worker went Offline mid-run
#   - #dispatch_queued!  sweep: claim + dispatch every Job still sitting queued
#
# Claiming is atomic (FOR UPDATE SKIP LOCKED) so two dispatches can never grab
# the same worker. A Job with no claim is simply left queued — it is picked up
# again as soon as a worker frees (requeue / sweep).
#
# Orphan recovery: a worker whose heartbeat went stale is marked Offline while
# its current Job is still mid-flight. That Job is reset and routed through
# JobRetrier as a worker_crash (retryable), exactly like any other infra
# failure — retried up to max_job_retries, then failed permanently.
class LoadBalancer
  # Raised by nothing here — just a typed error for orphan recovery so the
  # classifier can label the cause as a crashed worker.
  class WorkerCrashed < StandardError; end

  class << self
    # Assign the Job to the next available worker. Returns the claimed
    # WorkerHeartbeat, or nil when every worker is busy/offline.
    def claim!(job)
      WorkerRegistry.claim_available!(job)
    end

    # Put the Job back on the queue (with a small backoff) so it is retried
    # when a worker frees up. The Job stays :queued — nothing has run yet.
    def requeue!(job, backoff: nil)
      TestExecutionWorker.perform_in(backoff || retry_delay, job.id)
      Rails.logger.info("[LoadBalancer] All workers busy — Job ##{job.id} requeued")
      job
    end

    # Find every Job whose worker went Offline while executing it and route it
    # through the retry policy (worker_crash). Returns the number recovered.
    def recover_orphans!
      count = 0
      WorkerHeartbeat.offline.where.not(current_job_id: nil).find_each do |worker|
        job = worker.current_job
        next unless job && %w[running uploading_artifacts].include?(job.status)

        worker.update!(current_job_id: nil)
        reset_job_for_redispatch(job)
        JobRetrier.call(job, WorkerCrashed.new("worker #{worker.worker_name} went offline mid-run"), type: :worker_crash)
        Rails.logger.warn("[LoadBalancer] Recovered orphaned Job ##{job.id} (worker #{worker.worker_name} offline)")
        count += 1
      end
      count
    end

    # Sweep: claim and dispatch any Job still sitting in the queued state
    # (e.g. left behind by a crash between creation and dispatch). Returns the
    # number of Jobs actually dispatched. A limit prevents one sweep from
    # over-pushing when only some workers are free.
    def dispatch_queued!(limit: nil)
      count = 0
      Job.queued.order(:chunk_number).each do |job|
        break if limit && count >= limit

        worker = WorkerRegistry.claim_available!(job)
        next unless worker

        TestExecutionWorker.perform_async(job.id)
        Rails.logger.info("[LoadBalancer] Dispatched Job ##{job.id} to #{worker.worker_name}")
        count += 1
      end
      count
    end

    def retry_delay
      Rails.configuration.executehub.fetch("retry_delay_seconds", 5).to_i
    end
  end

  private

  # Clear the in-flight state left behind by the dead worker so the retried
  # run starts from a clean slate.
  def self.reset_job_for_redispatch(job)
    job.update!(started_at: nil, finished_at: nil, container_id: nil)
  end
end

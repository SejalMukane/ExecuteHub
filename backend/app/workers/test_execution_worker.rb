# TestExecutionWorker picks a Job up off the "test_execution" queue and hands
# it to WorkerExecutor, which runs the real Playwright execution inside a
# Docker container and owns the Job's lifecycle (running -> uploading_artifacts
# -> completed/failed).
#
# Load balancing (Part 8): before executing, the worker CLAIMS an available
# logical worker from the registry. If every worker is busy the Job is
# requeued with a small backoff instead of piling onto the pool — jobs are only
# ever assigned to workers that are actually free. When execution finishes the
# claimed worker is released back to Idle. Orphaned jobs (worker died mid-run)
# are recovered separately by LoadBalancer.
#
# This worker contains no Docker or Playwright logic itself — WorkerExecutor
# is kept Sidekiq-free and reusable, and this class is only the Sidekiq bridge.
class TestExecutionWorker
  include Sidekiq::Worker

  # Automatic retries are handled by JobRetrier (max 3, only for infra failures)
  # so retry_count + retry history are persisted. Sidekiq's own retry is
  # disabled to avoid unrecorded re-runs.
  sidekiq_options queue: "test_execution", retry: false, backtrace: true

  def perform(job_id)
    job = Job.find_by(id: job_id)
    if job.nil?
      Rails.logger.warn("[TestExecutionWorker] Job ##{job_id} not found — skipping.")
      return
    end

    worker = WorkerRegistry.claim_available!(job)
    if worker.nil?
      Rails.logger.warn("[TestExecutionWorker] No available worker — requeuing Job ##{job.id}")
      return LoadBalancer.requeue!(job)
    end

    Rails.logger.info("[TestExecutionWorker] Executing Job ##{job.id} on #{worker.worker_name}")
    begin
      WorkerExecutor.execute(job, worker: worker)
    ensure
      WorkerRegistry.release!(worker)
    end
  rescue StandardError => e
    # Safety net for failures that escape WorkerExecutor (e.g. DB down).
    Rails.logger.error("[TestExecutionWorker] Job ##{job_id} failed: #{e.message}")
    job = Job.find_by(id: job_id)
    job&.mark_failed!
    TestRunProgressUpdater.call(job.test_run) if job&.test_run
    raise
  end
end
